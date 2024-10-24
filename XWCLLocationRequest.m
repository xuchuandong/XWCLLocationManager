//
//  XWCLLocationRequest.m
//
//  Copyright (c) 2024 XuanWu.
//

#import "XWCLLocationRequest.h"

#import "XWCLRequestID.h"

@interface XWCLLocationRequest ()

// 将此属性重新声明为readwrite以供内部使用。
@property (nonatomic, assign, readwrite) BOOL hasTimedOut;

/** NSDate表示请求开始的时间。设置|timeout|属性时设置。*/
@property (nonatomic, strong) NSDate *requestStartTime;
/** 将触发计时器以通知此请求已超时。设置|timeout|属性时开始。 */
@property (nonatomic, strong) NSTimer *timeoutTimer;

@end


@implementation XWCLLocationRequest

/**
 当您尝试使用非指定的初始化器创建位置请求时，抛出一个exeption。
 */
- (instancetype)init
{
    @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"Must use initWithType: instead." userInfo:nil];
    return [self initWithType:XWCLLocationRequestTypeSingle];
}

/**
 指定初始化器。初始化并返回具有指定类型的新分配的位置请求对象。
 
 @param type 位置请求的类型。
 */
- (instancetype)initWithType:(XWCLLocationRequestType)type
{
    self = [super init];
    if (self) {
        _requestID = [XWCLRequestID getUniqueRequestID];
        _type = type;
        _hasTimedOut = NO;
    }
    return self;
}

/**
 返回位置请求所需精度级别的相关最近阈值（秒）。
 */
- (NSTimeInterval)updateTimeStaleThreshold
{
    switch (self.desiredAccuracy) {
        case XWCLLocationAccuracyRoom:
            return kXWCLUpdateTimeStaleThresholdRoom;
            break;
        case XWCLLocationAccuracyHouse:
            return kXWCLUpdateTimeStaleThresholdHouse;
            break;
        case XWCLLocationAccuracyBlock:
            return kXWCLUpdateTimeStaleThresholdBlock;
            break;
        case XWCLLocationAccuracyNeighborhood:
            return kXWCLUpdateTimeStaleThresholdNeighborhood;
            break;
        case XWCLLocationAccuracyCity:
            return kXWCLUpdateTimeStaleThresholdCity;
            break;
        default:
            NSAssert(NO, @"Unknown desired accuracy.");
            return 0.0;
            break;
    }
}

/**
 返回位置请求所需精度级别的相关水平精度阈值（单位：米）。
 */
- (CLLocationAccuracy)horizontalAccuracyThreshold
{
    switch (self.desiredAccuracy) {
        case XWCLLocationAccuracyRoom:
            return kXWCLHorizontalAccuracyThresholdRoom;
            break;
        case XWCLLocationAccuracyHouse:
            return kXWCLHorizontalAccuracyThresholdHouse;
            break;
        case XWCLLocationAccuracyBlock:
            return kXWCLHorizontalAccuracyThresholdBlock;
            break;
        case XWCLLocationAccuracyNeighborhood:
            return kXWCLHorizontalAccuracyThresholdNeighborhood;
            break;
        case XWCLLocationAccuracyCity:
            return kXWCLHorizontalAccuracyThresholdCity;
            break;
        default:
            NSAssert(NO, @"Unknown desired accuracy.");
            return 0.0;
            break;
    }
}

/**
 完成定位请求。
 */
- (void)complete
{
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
    self.requestStartTime = nil;
}

/**
 强制定位请求认为自己已超时。
 */
- (void)forceTimeout
{
    if (self.isRecurring == NO) {
        self.hasTimedOut = YES;
    } else {
        NSAssert(self.isRecurring == NO, @"Only single location requests (not recurring requests) should ever be considered timed out.");
    }
}

/**
 取消定位请求。
 */
- (void)cancel
{
    [self.timeoutTimer invalidate];
    self.timeoutTimer = nil;
    self.requestStartTime = nil;
}

/**
 如果设置了非零超时值，并且计时器尚未启动，则启动位置请求的超时计时器。
 */
- (void)startTimeoutTimerIfNeeded
{
    if (self.timeout > 0 && !self.timeoutTimer) {
        self.requestStartTime = [NSDate date];
        self.timeoutTimer = [NSTimer scheduledTimerWithTimeInterval:self.timeout target:self selector:@selector(timeoutTimerFired:) userInfo:nil repeats:NO];
    }
}

/**
 返回这是否是订阅请求的计算属性。
 */
- (BOOL)isRecurring
{
    return (self.type == XWCLLocationRequestTypeSubscription) || (self.type == XWCLLocationRequestTypeSignificantChanges);
}

/**
 计算属性，返回请求存活的时间（自设置超时值以来）。
 */
- (NSTimeInterval)timeAlive
{
    if (self.requestStartTime == nil) {
        return 0.0;
    }
    return fabs([self.requestStartTime timeIntervalSinceNow]);
}

/**
 返回位置请求是否已超时。
 一旦变为“是”，即使设置了新的超时值，它也不会自动重置为“否”。
 */
- (BOOL)hasTimedOut
{
    if (self.timeout > 0.0 && self.timeAlive > self.timeout) {
        _hasTimedOut = YES;
    }
    return _hasTimedOut;
}

/**
 当超时定时器触发时进行回调。通知代理人此事件已发生。
 */
- (void)timeoutTimerFired:(NSTimer *)timer
{
    self.hasTimedOut = YES;
    [self.delegate locationRequestDidTimeout:self];
}

/**
 如果两个位置请求的请求ID匹配，则认为它们相等。
 */
- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[self class]]) {
        return NO;
    }
    if (((XWCLLocationRequest *)object).requestID == self.requestID) {
        return YES;
    }
    return NO;
}

/**
 根据请求ID的字符串表示返回哈希值。
 */
- (NSUInteger)hash
{
    return [[NSString stringWithFormat:@"%ld", (long)self.requestID] hash];
}

- (void)dealloc
{
    [_timeoutTimer invalidate];
}

@end
