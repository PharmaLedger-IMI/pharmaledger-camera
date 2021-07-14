//
//  WebsocketServer.swift
//  WkCamera
//
//  Created by Yves Delacrétaz on 06.07.21.
//

import NIO
import NIOHTTP1
import NIOWebSocket
import Foundation

public class WebSocketVideoFrameServer {
    static let shared = WebSocketVideoFrameServer()
    
    private var group: EventLoopGroup?
    private var videoFrameHandler: WebSocketVideoFrameHandler?
    private var upgrader: HTTPServerProtocolUpgrader?
    private var bootstrap: ServerBootstrap?
    private var channel: Channel?
    private var port = 0
    
    private init() {
    }
    
    public func start(completion: (() -> Void)?) {
        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        guard group != nil else {
            print("group was nil")
            return
        }
        videoFrameHandler = WebSocketVideoFrameHandler()
        guard videoFrameHandler != nil else {
            print("videoFrameHandler was nil")
            return
        }
        /// TODO: find a way to get rid of http upgrade
        upgrader = NIOWebSocketServerUpgrader(shouldUpgrade: {(channel: Channel, head: HTTPRequestHead) in
            channel.eventLoop.makeSucceededFuture(HTTPHeaders())
        }, upgradePipelineHandler: {(channel: Channel, _: HTTPRequestHead) in
            channel.pipeline.addHandler(self.videoFrameHandler!)
        })

        bootstrap = ServerBootstrap(group: group!)
            .serverChannelOption(ChannelOptions.backlog, value: 1)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
             // Set the handlers that are applied to the accepted Channels
            .childChannelInitializer({ channel in
                let httpHandler = HTTPHandler()
                let config: NIOHTTPServerUpgradeConfiguration = (
                    upgraders: [ self.upgrader! ],
                    completionHandler: { _ in
                        channel.pipeline.removeHandler(httpHandler, promise: nil)
                    }
                )
                return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: config).flatMap {
                    channel.pipeline.addHandler(httpHandler)
                }
            })
            // Enable SO_REUSEADDR for the accepted Channels
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
        
        
        port = WebSocketVideoFrameServer.findFreePort()
        if let bootstrap = bootstrap {
            let channelEvtFutureLoop = bootstrap.bind(host: "localhost", port: port)
            channelEvtFutureLoop.whenSuccess({channel in
                self.channel = channel
                print("server started at \(channel.localAddress!)")
                if let completion = completion {
                    completion()
                }
            })
            channelEvtFutureLoop.whenFailure({_ in
                print("failed to create channel")
            })
        } else {
            print("Failed to create server bootstrap")
        }
    }
    
    public var serverPort: Int { return port }
    
    public func stop() {
        group!.shutdownGracefully({err in
            if let error = err {
                print(error)
            } else {
                print("websocket server stopped")
            }
            self.channel = nil
            self.bootstrap = nil
            self.upgrader = nil
            self.videoFrameHandler = nil
            self.group = nil
        })
    }
    
    public func sendFrame(frame: Data?) {
        if let vfh = videoFrameHandler {
            if let frame = frame {
                vfh.currentFrame = frame
            }
        }
    }
    
    public static func findFreePort() -> Int {
        var port: UInt16 = 8000;
        
        let socketFD = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
        if socketFD == -1 {
            //print("Error creating socket: \(errno)")
            return Int(port);
        }
        
        var hints = addrinfo(
            ai_flags: AI_PASSIVE,
            ai_family: AF_INET,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        );
        
        var addressInfo: UnsafeMutablePointer<addrinfo>? = nil;
        var result = getaddrinfo(nil, "0", &hints, &addressInfo);
        if result != 0 {
            //print("Error getting address info: \(errno)")
            close(socketFD);
            
            return Int(port);
        }
        
        result = Darwin.bind(socketFD, addressInfo!.pointee.ai_addr, socklen_t(addressInfo!.pointee.ai_addrlen));
        if result == -1 {
            //print("Error binding socket to an address: \(errno)")
            close(socketFD);
            
            return Int(port);
        }
        
        result = Darwin.listen(socketFD, 1);
        if result == -1 {
            //print("Error setting socket to listen: \(errno)")
            close(socketFD);
            
            return Int(port);
        }
        
        var addr_in = sockaddr_in();
        addr_in.sin_len = UInt8(MemoryLayout.size(ofValue: addr_in));
        addr_in.sin_family = sa_family_t(AF_INET);
        
        var len = socklen_t(addr_in.sin_len);
        result = withUnsafeMutablePointer(to: &addr_in, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                return Darwin.getsockname(socketFD, $0, &len);
            }
        });
        
        if result == 0 {
            port = addr_in.sin_port;
        }
        
        Darwin.shutdown(socketFD, SHUT_RDWR);
        close(socketFD);
        
        return Int(port);
    }
}



/// TODO: remove http handler and connect directly via ws://
private final class HTTPHandler: ChannelInboundHandler, RemovableChannelHandler {
    private let websocketResponse = "" // just use this first request for upgrade

    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private var responseBody: ByteBuffer!

    func handlerAdded(context: ChannelHandlerContext) {
        self.responseBody = context.channel.allocator.buffer(string: websocketResponse)
    }

    func handlerRemoved(context: ChannelHandlerContext) {
        self.responseBody = nil
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)

        // We're not interested in request bodies here: we're just serving up GET responses
        // to get the client to initiate a websocket request.
        guard case .head(let head) = reqPart else {
            return
        }

        // GETs only.
        guard case .GET = head.method else {
            self.respond405(context: context)
            return
        }

        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/html")
        headers.add(name: "Content-Length", value: String(self.responseBody.readableBytes))
        headers.add(name: "Connection", value: "close")
        let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1),
                                    status: .ok,
                                    headers: headers)
        context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(self.responseBody))), promise: nil)
        context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
            context.close(promise: nil)
        }
        context.flush()
    }

    private func respond405(context: ChannelHandlerContext) {
        var headers = HTTPHeaders()
        headers.add(name: "Connection", value: "close")
        headers.add(name: "Content-Length", value: "0")
        let head = HTTPResponseHead(version: .http1_1,
                                    status: .methodNotAllowed,
                                    headers: headers)
        context.write(self.wrapOutboundOut(.head(head)), promise: nil)
        context.write(self.wrapOutboundOut(.end(nil))).whenComplete { (_: Result<Void, Error>) in
            context.close(promise: nil)
        }
        context.flush()
    }
}


