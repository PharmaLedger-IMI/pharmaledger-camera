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
    private init() {
    }
    
    public func send() {
        videoFrameHandler?.semaphore.signal();
    }
        
    public func start(completion: (() -> Void)?) {
        group = MultiThreadedEventLoopGroup(numberOfThreads: 5)
        guard group != nil else {
            print("group was nil")
            return
        }
        videoFrameHandler = WebSocketVideoFrameHandler()
        guard videoFrameHandler != nil else {
            print("videoFrameHandler was nil")
            return
        }
        upgrader = NIOWebSocketServerUpgrader(shouldUpgrade: {(channel: Channel, head: HTTPRequestHead) in
            channel.eventLoop.makeSucceededFuture(HTTPHeaders())
        }, upgradePipelineHandler: {(channel: Channel, _: HTTPRequestHead) in
            channel.pipeline.addHandler(self.videoFrameHandler!)
        })
        /// TODO: find a way to get rid of http upgrade, should be smthg like the below (taken from the doc of ServerBootstrap class)
//        bootstrap = ServerBootstrap(group: group!)
//            .serverChannelOption(ChannelOptions.backlog, value: 256)
//            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
//            .childChannelInitializer({channel in
//                channel.pipeline.addHandler(BackPressureHandler()).flatMap({() in
//                    channel.pipeline.addHandler(self.videoFrameHandler!)
//                })
//            })
//            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
//            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
//            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        
        bootstrap = ServerBootstrap(group: group!)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
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
        
        if let bootstrap = bootstrap {
            let channelEvtFutureLoop = bootstrap.bind(host: "localhost", port: 8888)
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
    
    public func stop() {
        do {
            try group!.syncShutdownGracefully()
            print("websocket server stopped")
            channel = nil
            bootstrap = nil
            upgrader = nil
            videoFrameHandler = nil
            group = nil
            
        } catch {
            print(error)
        }
    }
    
    public func storeFrame(frame: [UInt8]) {
        if let vfh = videoFrameHandler {
            vfh.currentFrame = frame
        }
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


