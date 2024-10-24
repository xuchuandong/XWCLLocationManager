//
//  XWCLLocationRequest.h
//
//  Copyright (c) 2024 XuanWu.
//

#import "XWCLLocationDefines.h"

__XWCL_ASSUME_NONNULL_BEGIN

/** 位置请求类型。*/
typedef NS_ENUM(NSInteger, XWCLLocationRequestType) {
    /** 具有特定所需精度和可选超时的一次性位置请求。*/
    XWCLLocationRequestTypeSingle,
    /** 订阅位置更新。 */
    XWCLLocationRequestTypeSubscription,
    /** 订阅重大位置更改。 */
    XWCLLocationRequestTypeSignificantChanges
};

@class XWCLLocationRequest;

/**
 XWCLLLocationRequest协议，用于通知其代理请求已超时。
 */
@protocol XWCLLocationRequestDelegate

/**
 位置请求已超时的通知。
 
 @param locationRequest 超时的位置请求。
 */
- (void)locationRequestDidTimeout:(XWCLLocationRequest *)locationRequest;

@end


/**
 由XWCLLLocationManager创建和管理的地理定位请求。
 */
@interface XWCLLocationRequest : NSObject

/** 位置请求代理 */
@property (nonatomic, weak, __XWCL_NULLABLE) id<XWCLLocationRequestDelegate> delegate;
/** 位置请求ID (初始化已设置). */
@property (nonatomic, readonly) XWCLLocationRequestID requestID;
/** 位置请求类型 (初始化已设置). */
@property (nonatomic, readonly) XWCLLocationRequestType type;
/** 是否为重复位置请求 （类型为认购或重大变更）。*/
@property (nonatomic, readonly) BOOL isRecurring;
/** 位置请求所需的精度。*/
@property (nonatomic, assign) XWCLLocationAccuracy desiredAccuracy;
/** 完成定位请求前允许的超时时长。
 如果此值恰好为0.0，则将被忽略（请求本身永远不会超时）。*/
@property (nonatomic, assign) NSTimeInterval timeout;
/** 自上次设置超时值以来，位置请求已存活多长时间。*/
@property (nonatomic, readonly) NSTimeInterval timeAlive;
/** 此位置请求是否已超时（如果已完成，也将为“是”）。订阅永远不会超时。 */
@property (nonatomic, readonly) BOOL hasTimedOut;
/** 位置请求完成时要执行的block。 */
@property (nonatomic, copy, __XWCL_NULLABLE) XWCLLocationRequestBlock block;

/** 指定初始化器。初始化并返回新分配的具有指定类型的位置请求对象。 */
- (instancetype)initWithType:(XWCLLocationRequestType)type __XWCL_DESIGNATED_INITIALIZER;

/** 完成定位请求。*/
- (void)complete;
/** 强制定位请求认为自己已超时。 */
- (void)forceTimeout;
/** 取消定位请求。*/
- (void)cancel;

/** 如果设置了非零超时值，并且计时器尚未启动，则启动位置请求的超时计时器。 */
- (void)startTimeoutTimerIfNeeded;

/** 返回位置请求所需精度级别的相关最近阈值（秒）。*/
- (NSTimeInterval)updateTimeStaleThreshold;

/** 返回位置请求所需精度级别的相关水平精度阈值（单位：米）。 */
- (CLLocationAccuracy)horizontalAccuracyThreshold;

@end

__XWCL_ASSUME_NONNULL_END
