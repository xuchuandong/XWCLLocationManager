//
//  XWCLLocationManager.h
//
//  Copyright (c) 2024 XuanWu.
//

#import "XWCLLocationDefines.h"

__XWCL_ASSUME_NONNULL_BEGIN

/**
 围绕CLLocationManager的抽象，提供基于块的异步API来获取设备的位置。
 XWCLLLocationManager会根据需要自动启动和停止系统定位服务，以最大限度地减少电池消耗。
 */
@interface XWCLLocationManager : NSObject

/** 根据系统设置和用户授权状态，返回此应用程序的位置服务的当前状态。 */
+ (XWCLLocationServicesState)locationServicesState;

/** 返回此设备的航向服务的当前状态。 */
+ (XWCLHeadingServicesState)headingServicesState;

/** 返回此类的单例实例。 */
+ (instancetype)sharedInstance;

#pragma mark Location Requests

/**
 使用位置服务异步请求设备的当前位置。
 
 @param desiredAccuracy 所需的精度水平（指位置的精度和新近度）。
 @param timeout         在完成之前等待具有所需精度的位置的最长时间（秒）。如果此值为0.0，则不会设置超时（将无限期等待成功，除非请求被强制完成或取消）。
 @param block           成功、失败或超时时执行的块。
 
 @return 位置请求ID，可用于强制提前完成或在请求进行时取消请求。
 */
- (XWCLLocationRequestID)requestLocationWithDesiredAccuracy:(XWCLLocationAccuracy)desiredAccuracy
                                                    timeout:(NSTimeInterval)timeout
                                                      block:(XWCLLocationRequestBlock)block;

/**
 使用位置服务异步请求设备的当前位置，可以选择延迟超时倒计时，直到用户对请求允许此应用访问位置服务的对话框做出响应。
 
 @param desiredAccuracy     所需的精度水平（指位置的精度和新近度）。
 @param timeout             在完成之前等待具有所需精度的位置的最长时间（秒）。如果此值为0.0，则不会设置超时（将无限期等待成功，除非请求被强制完成或取消）。
 @param delayUntilAuthorized 一个标志，指定超时是否只有在用户响应系统提示请求允许此应用访问位置服务后才生效。
                            如果是，则超时倒计时将在应用程序收到位置服务权限后开始。如果为“否”，则调用此方法时将立即开始超时倒计时。
 @param block                成功、失败或超时时执行的块。
 
 @return 位置请求ID，可用于强制提前完成或在请求进行时取消请求。
 */
- (XWCLLocationRequestID)requestLocationWithDesiredAccuracy:(XWCLLocationAccuracy)desiredAccuracy
                                                    timeout:(NSTimeInterval)timeout
                                       delayUntilAuthorized:(BOOL)delayUntilAuthorized
                                                      block:(XWCLLocationRequestBlock)block;

/**
 创建位置更新的订阅，该订阅将无限期地每次更新执行一次块（直到取消），而不管每个位置的准确性如何。
 此方法指示位置服务使用可用的最高精度（这也需要最大的功率）。
 如果发生错误，该块将以XWCLLocationStatusSuccess以外的状态执行，订阅将自动取消。
 
 @param block 每次更新位置可用时执行的块。
                除非发生错误，否则状态将为XWCLLocationStatusSuccess；它永远不会是XWCLL位置状态超时。
 
 @return 位置请求ID，可用于取消对此块的位置更新订阅。
 */
- (XWCLLocationRequestID)subscribeToLocationUpdatesWithBlock:(XWCLLocationRequestBlock)block;

/**
 创建位置更新的订阅，该订阅将无限期地每次更新执行一次块（直到取消），而不管每个位置的准确性如何。
 指定的所需精度被传递给位置服务，并控制使用多少功率，更高的精度使用更多的功率。
 如果发生错误，该块将以XWCLLocationStatusSuccess以外的状态执行，订阅将自动取消。
 
 @param desiredAccuracy 所需的精度级别，控制设备的位置服务使用多少功率。
 @param block          每次更新位置可用时执行的块。请注意，此块在每次更新时都会运行，无论实现的Accuracy是否至少是所需的Accurability。
                    除非发生错误，否则状态将为XWCLLocationStatusSuccess；它永远不会是XWCLL位置状态超时。
 
 @return 位置请求ID，可用于取消对此块的位置更新订阅。
 */
- (XWCLLocationRequestID)subscribeToLocationUpdatesWithDesiredAccuracy:(XWCLLocationAccuracy)desiredAccuracy
                                                                 block:(XWCLLocationRequestBlock)block;

/**
 为重大位置更改创建订阅，每次更改将无限期执行一次块（直到取消）。
 如果发生错误，该块将以XWCLLocationStatusSuccess以外的状态执行，订阅将自动取消。
 
 @param block 每次更新位置可用时执行的块。
             除非发生错误，否则状态将为XWCLLocationStatusSuccess；它永远不会是XWCLL位置状态超时。
 
 @return 位置请求ID，可用于取消对此块的重大位置更改的订阅。
 */
- (XWCLLocationRequestID)subscribeToSignificantLocationChangesWithBlock:(XWCLLocationRequestBlock)block;

/** 立即使用给定的requestID（如果存在）强制完成位置请求，并使用结果执行原始请求块。
 对于一次性位置请求，这实际上是一个手动超时，将导致请求完成，状态为XWCLLLocationStatusTimedOut。
 如果requestID对应于订阅，则订阅将被取消。 */
- (void)forceCompleteLocationRequest:(XWCLLocationRequestID)requestID;

/** 立即取消具有给定requestID（如果存在）的位置请求（或订阅），而不执行原始请求块。 */
- (void)cancelLocationRequest:(XWCLLocationRequestID)requestID;

#pragma mark Heading Requests

/**
 为航向更新创建订阅，假设航向更新超过航向过滤器阈值，则每次更新将无限期执行一次阻止（直到取消）。
 如果发生错误，该块将以XWCLHeadingStatusSuccess以外的状态执行，订阅将自动取消。

 @param block           每次有更新的航向可用时执行的块。除非发生错误，否则状态将为XWCLHeadingStatusSuccess。

 @return 航向请求ID，可用于取消订阅此块的航向更新。
 */
- (XWCLHeadingRequestID)subscribeToHeadingUpdatesWithBlock:(XWCLHeadingRequestBlock)block;

/** 立即取消具有给定requestID（如果存在）的航向订阅请求，而不执行原始请求块。 */
- (void)cancelHeadingRequest:(XWCLHeadingRequestID)requestID;

@end

__XWCL_ASSUME_NONNULL_END
