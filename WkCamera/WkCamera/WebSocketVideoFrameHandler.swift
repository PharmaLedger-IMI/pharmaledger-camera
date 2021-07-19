//
//  WebSocketFrameHandler.swift
//  WkCamera
//
//  Created by Yves Delacrétaz on 06.07.21.
//

import NIO
import NIOWebSocket
import Foundation

public class WebSocketVideoFrameHandler: ChannelInboundHandler {
    public typealias InboundIn = WebSocketFrame
    public typealias OutboundOut = WebSocketFrame
    
    private var awaitingClose: Bool = false
    private let bandwidthLimit = 42.0*1024.0*1024.0 // in B/s
    
    public var currentFrame: Data?
    public let semaphore = DispatchSemaphore(value: 1)

    
    public func handlerAdded(context: ChannelHandlerContext) {
        print("handler added")
        self.sendFrame(context: context)
    }
    
    public func channelActive(context: ChannelHandlerContext) {
        print("channel active")
    }

    public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = self.unwrapInboundIn(data)

        switch frame.opcode {
        case .connectionClose:
            self.receivedClose(context: context, frame: frame)
        case .ping:
            self.pong(context: context, frame: frame)
        case .text:
            var data = frame.unmaskedData
            let text = data.readString(length: data.readableBytes) ?? ""
            print(text)
       case .binary, .continuation, .pong:
            // We ignore these frames.
            break
        default:
            // Unknown frames are errors.
            self.closeOnError(context: context)
        }
    }

    public func channelReadComplete(context: ChannelHandlerContext) {
        context.flush()
    }

    public func sendFrame(context: ChannelHandlerContext) {
        semaphore.wait();
        guard context.channel.isActive else {
            return
        }

        // We can't send if we sent a close message.
        guard !self.awaitingClose else {
            return
        }
        
        var byteBuffer: ByteBuffer?
        var nextDelay = 50000.0
        if let aFrame = currentFrame {
            byteBuffer = context.channel.allocator.buffer(bytes: aFrame)
            nextDelay = Double(aFrame.count) / bandwidthLimit * 1e6 * 0.9 // <-- empirical adaptation factor
        } else {
            byteBuffer = context.channel.allocator.buffer(bytes: [UInt8(0)])
        }
        let frame = WebSocketFrame(fin: true, opcode: .binary, data: byteBuffer!)
        context.channel.writeAndFlush(self.wrapOutboundOut(frame)).whenComplete({res in
            switch res {
            case .success():
//                self.sendFrame(context: context)
                context.eventLoop.scheduleTask(in: .microseconds(Int64(nextDelay)), { self.sendFrame(context: context) })
            case .failure(let err):
                print(err)
                context.close(promise: nil)
            }
        })
    }

    private func receivedClose(context: ChannelHandlerContext, frame: WebSocketFrame) {
        // Handle a received close frame. In websockets, we're just going to send the close
        // frame and then close, unless we already sent our own close frame.
        if awaitingClose {
            // Cool, we started the close and were waiting for the user. We're done.
            context.close(promise: nil)
        } else {
            // This is an unsolicited close. We're going to send a response frame and
            // then, when we've sent it, close up shop. We should send back the close code the remote
            // peer sent us, unless they didn't send one at all.
            var data = frame.unmaskedData
            let closeDataCode = data.readSlice(length: 2) ?? ByteBuffer()
            let closeFrame = WebSocketFrame(fin: true, opcode: .connectionClose, data: closeDataCode)
            _ = context.write(self.wrapOutboundOut(closeFrame)).map { () in
                context.close(promise: nil)
            }
        }
    }

    private func pong(context: ChannelHandlerContext, frame: WebSocketFrame) {
        var frameData = frame.data
        let maskingKey = frame.maskKey

        if let maskingKey = maskingKey {
            frameData.webSocketUnmask(maskingKey)
        }

        let responseFrame = WebSocketFrame(fin: true, opcode: .pong, data: frameData)
        context.write(self.wrapOutboundOut(responseFrame), promise: nil)
    }

    private func closeOnError(context: ChannelHandlerContext) {
        // We have hit an error, we want to close. We do that by sending a close frame and then
        // shutting down the write side of the connection.
        var data = context.channel.allocator.buffer(capacity: 2)
        data.write(webSocketErrorCode: .protocolError)
        let frame = WebSocketFrame(fin: true, opcode: .connectionClose, data: data)
        context.write(self.wrapOutboundOut(frame)).whenComplete { (_: Result<Void, Error>) in
            context.close(mode: .output, promise: nil)
        }
        awaitingClose = true
    }
}
