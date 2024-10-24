//
//  XWCLLocationManager.m
//
//  Copyright (c) 2024 XuanWu.
//

#import "XWCLLocationManager.h"
#import "XWCLLocationRequest.h"
#import "XWCLHeadingRequest.h"


#ifndef XWCL_ENABLE_LOGGING
#   ifdef DEBUG
#       define XWCL_ENABLE_LOGGING 1
#   else
#       define XWCL_ENABLE_LOGGING 0
#   endif /* DEBUG */
#endif /* XWCL_ENABLE_LOGGING */

#if XWCL_ENABLE_LOGGING
#   define XWCLLMLog(...)          NSLog(@"XWCLLocationManager: %@", [NSString stringWithFormat:__VA_ARGS__]);
#else
#   define XWCLLMLog(...)
#endif /* XWCL_ENABLE_LOGGING */


@interface XWCLLocationManager () <CLLocationManagerDelegate, XWCLLocationRequestDelegate>

/** 此类封装的CLLocationManager实例。 */
@property (nonatomic, strong) CLLocationManager *locationManager;
/** 最近的当前位置，如果当前位置未知、无效或过时，则为nil。*/
@property (nonatomic, strong) CLLocation *currentLocation;
/** 最新的当前航向，如果当前航向未知、无效或过时，则为nil。 */
@property (nonatomic, strong) CLHeading *currentHeading;
/** CLLocationManager当前是否正在监控重大的位置变化。 */
@property (nonatomic, assign) BOOL isMonitoringSignificantLocationChanges;
/** CLLocationManager当前是否正在发送位置更新。*/
@property (nonatomic, assign) BOOL isUpdatingLocation;
/** CLLocationManager当前是否正在发送航向更新。*/
@property (nonatomic, assign) BOOL isUpdatingHeading;
/** 上次位置更新期间是否发生错误。 */
@property (nonatomic, assign) BOOL updateFailed;

// 一系列活动位置请求，格式如下：
// @[ XWCLLocationRequest *locationRequest1, XWCLLocationRequest *locationRequest2, ... ]
@property (nonatomic, strong) __XWCL_GENERICS(NSArray, XWCLLocationRequest *) *locationRequests;

// 一系列活动航向请求，格式如下：
// @[ XWCLHeadingRequest *headingRequest1, XWCLHeadingRequest *headingRequest2, ... ]
@property (nonatomic, strong) __XWCL_GENERICS(NSArray, XWCLHeadingRequest *) *headingRequests;

@end


@implementation XWCLLocationManager

static id _sharedInstance;

/**
 根据系统设置和用户授权状态，返回此应用程序的位置服务的当前状态。
 */
+ (XWCLLocationServicesState)locationServicesState
{
    if ([CLLocationManager locationServicesEnabled] == NO) {
        return XWCLLocationServicesStateDisabled;
    }
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        return XWCLLocationServicesStateNotDetermined;
    }
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
        return XWCLLocationServicesStateDenied;
    }
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted) {
        return XWCLLocationServicesStateRestricted;
    }
    
    return XWCLLocationServicesStateAvailable;
}

/** 
 返回此设备的航向服务的当前状态。
 */
+ (XWCLHeadingServicesState)headingServicesState
{
    if ([CLLocationManager headingAvailable]) {
        return XWCLHeadingServicesStateAvailable;
    } else {
        return XWCLHeadingServicesStateUnavailable;
    }
}

/**
 返回此类的单例实例。
 */
+ (instancetype)sharedInstance
{
    static dispatch_once_t _onceToken;
    dispatch_once(&_onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init
{
    NSAssert(_sharedInstance == nil, @"Only one instance of XWCLLocationManager should be created. Use +[XWCLLocationManager sharedInstance] instead.");
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        
#ifdef __IPHONE_8_4
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_8_4
        /* iOS 9需要将allowsBackgroundLocationUpdates设置为YES才能接收后台位置更新。
         仅当此应用程序启用了位置后台模式时，我们才将其设置为“是”，因为文档表明，否则这是一个致命的程序员错误。 */
        NSArray *backgroundModes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"];
        if ([backgroundModes containsObject:@"location"]) {
            if ([_locationManager respondsToSelector:@selector(setAllowsBackgroundLocationUpdates:)]) {
                [_locationManager setAllowsBackgroundLocationUpdates:YES];
            }
        }
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_8_4 */
#endif /* __IPHONE_8_4 */

        _locationRequests = @[];
    }
    return self;
}

#pragma mark Public location methods

/**
 使用位置服务异步请求设备的当前位置。
 
 @param desiredAccuracy 所需的精度水平（指位置的精度和新近度）。
 @param timeout         在完成之前等待具有所需精度的位置的最长时间（秒）。如果此值为0.0，则不会设置超时（将无限期等待成功，除非请求被强制完成或取消）。
 @param block           成功、失败或超时时执行的块。
 
 @return 位置请求ID，可用于强制提前完成或在请求进行时取消请求。
 */
- (XWCLLocationRequestID)requestLocationWithDesiredAccuracy:(XWCLLocationAccuracy)desiredAccuracy
                                                    timeout:(NSTimeInterval)timeout
                                                      block:(XWCLLocationRequestBlock)block
{
    return [self requestLocationWithDesiredAccuracy:desiredAccuracy
                                            timeout:timeout
                               delayUntilAuthorized:NO
                                              block:block];
}

/**
 使用位置服务异步请求设备的当前位置，可以选择延迟超时倒计时，直到用户对请求允许此应用访问位置服务的对话框做出响应。
 
 @param desiredAccuracy     所需的精度水平（指位置的精度和新近度）。
 @param timeout             在完成之前等待具有所需精度的位置的最长时间（秒）。如果此值为0.0，则不会设置超时（将无限期等待成功，除非请求被强制完成或取消）。
 @param delayUntilAuthorized 一个标志，指定超时是否只有在用户响应系统提示请求允许此应用访问位置服务后才生效。
                            如果是，则超时倒计时将在应用程序收到位置服务权限后开始。如果为“否”，则调用此方法时将立即开始超时倒计时。
 @param block                The block to execute upon success, failure, or timeout.
 
 @return 位置请求ID，可用于强制提前完成或在请求进行时取消请求。
 */
- (XWCLLocationRequestID)requestLocationWithDesiredAccuracy:(XWCLLocationAccuracy)desiredAccuracy
                                                    timeout:(NSTimeInterval)timeout
                                       delayUntilAuthorized:(BOOL)delayUntilAuthorized
                                                      block:(XWCLLocationRequestBlock)block
{
    NSAssert([NSThread isMainThread], @"XWCLLocationManager should only be called from the main thread.");
    
    if (desiredAccuracy == XWCLLocationAccuracyNone) {
        NSAssert(desiredAccuracy != XWCLLocationAccuracyNone, @"XWCLLocationAccuracyNone is not a valid desired accuracy.");
        desiredAccuracy = XWCLLocationAccuracyCity; // default to the lowest valid desired accuracy
    }
    
    XWCLLocationRequest *locationRequest = [[XWCLLocationRequest alloc] initWithType:XWCLLocationRequestTypeSingle];
    locationRequest.delegate = self;
    locationRequest.desiredAccuracy = desiredAccuracy;
    locationRequest.timeout = timeout;
    locationRequest.block = block;
    
//    BOOL deferTimeout = delayUntilAuthorized && ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined);
//    if (!deferTimeout) {
//        [locationRequest startTimeoutTimerIfNeeded];
//    }
    
    [self addLocationRequest:locationRequest];
    
    return locationRequest.requestID;
}

/**
 创建位置更新的订阅，该订阅将无限期地每次更新执行一次块（直到取消），而不管每个位置的准确性如何。
 此方法指示位置服务使用可用的最高精度（这也需要最大的功率）。
 如果发生错误，该块将以XWCLLocationStatusSuccess以外的状态执行，订阅将自动取消。
 
 @param block 每次更新位置可用时执行的块。
                除非发生错误，否则状态将为XWCLLocationStatusSuccess；它永远不会是XWCLL位置状态超时。
 
 @return 位置请求ID，可用于取消对此块的位置更新订阅。
 */
- (XWCLLocationRequestID)subscribeToLocationUpdatesWithBlock:(XWCLLocationRequestBlock)block
{
    return [self subscribeToLocationUpdatesWithDesiredAccuracy:XWCLLocationAccuracyRoom
                                                         block:block];
}

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
                                                                 block:(XWCLLocationRequestBlock)block
{
    NSAssert([NSThread isMainThread], @"XWCLLocationManager should only be called from the main thread.");
    
    XWCLLocationRequest *locationRequest = [[XWCLLocationRequest alloc] initWithType:XWCLLocationRequestTypeSubscription];
    locationRequest.desiredAccuracy = desiredAccuracy;
    locationRequest.block = block;
    
    [self addLocationRequest:locationRequest];
    
    return locationRequest.requestID;
}

/**
 为重大位置更改创建订阅，每次更改将无限期执行一次块（直到取消）。
 如果发生错误，该块将以XWCLLocationStatusSuccess以外的状态执行，订阅将自动取消。
 
 @param block 每次更新位置可用时执行的块。
             除非发生错误，否则状态将为XWCLLocationStatusSuccess；它永远不会是XWCLL位置状态超时。
 
 @return 位置请求ID，可用于取消对此块的重大位置更改的订阅。
 */
- (XWCLLocationRequestID)subscribeToSignificantLocationChangesWithBlock:(XWCLLocationRequestBlock)block
{
    NSAssert([NSThread isMainThread], @"XWCLLocationManager should only be called from the main thread.");
    
    XWCLLocationRequest *locationRequest = [[XWCLLocationRequest alloc] initWithType:XWCLLocationRequestTypeSignificantChanges];
    locationRequest.block = block;
    
    [self addLocationRequest:locationRequest];
    
    return locationRequest.requestID;
}

/** 立即使用给定的requestID（如果存在）强制完成位置请求，并使用结果执行原始请求块。
 对于一次性位置请求，这实际上是一个手动超时，将导致请求完成，状态为XWCLLLocationStatusTimedOut。
 如果requestID对应于订阅，则订阅将被取消。 */
- (void)forceCompleteLocationRequest:(XWCLLocationRequestID)requestID
{
    NSAssert([NSThread isMainThread], @"XWCLLocationManager should only be called from the main thread.");
    
    for (XWCLLocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.requestID == requestID) {
            if (locationRequest.isRecurring) {
                // Recurring requests can only be canceled
                [self cancelLocationRequest:requestID];
            } else {
                [locationRequest forceTimeout];
                [self completeLocationRequest:locationRequest];
            }
            break;
        }
    }
}

/** 立即取消具有给定requestID（如果存在）的位置请求（或订阅），而不执行原始请求块。 */
- (void)cancelLocationRequest:(XWCLLocationRequestID)requestID
{
    NSAssert([NSThread isMainThread], @"XWCLLocationManager should only be called from the main thread.");
    
    for (XWCLLocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.requestID == requestID) {
            [locationRequest cancel];
            XWCLLMLog(@"Location Request canceled with ID: %ld", (long)locationRequest.requestID);
            [self removeLocationRequest:locationRequest];
            break;
        }
    }
}

#pragma mark Public heading methods

/**
 为航向更新创建订阅，假设航向更新超过航向过滤器阈值，则每次更新将无限期执行一次阻止（直到取消）。
 如果发生错误，该块将以XWCLHeadingStatusSuccess以外的状态执行，订阅将自动取消。

 @param block           每次有更新的航向可用时执行的块。除非发生错误，否则状态将为XWCLHeadingStatusSuccess。

 @return 航向请求ID，可用于取消订阅此块的航向更新。
 */
- (XWCLHeadingRequestID)subscribeToHeadingUpdatesWithBlock:(XWCLHeadingRequestBlock)block
{
    XWCLHeadingRequest *headingRequest = [[XWCLHeadingRequest alloc] init];
    headingRequest.block = block;

    [self addHeadingRequest:headingRequest];

    return headingRequest.requestID;
}

/** 立即取消具有给定requestID（如果存在）的航向订阅请求，而不执行原始请求块。 */
- (void)cancelHeadingRequest:(XWCLHeadingRequestID)requestID
{
    for (XWCLHeadingRequest *headingRequest in self.headingRequests) {
        if (headingRequest.requestID == requestID) {
            [self removeHeadingRequest:headingRequest];
            XWCLLMLog(@"Heading Request canceled with ID: %ld", (long)headingRequest.requestID);
            break;
        }
    }
}

#pragma mark Internal location methods

/**
 将给定的位置请求添加到请求数组中，更新所需的最大精度，并在需要时启动位置更新。
 */
- (void)addLocationRequest:(XWCLLocationRequest *)locationRequest
{
    XWCLLocationServicesState locationServicesState = [XWCLLocationManager locationServicesState];
    if (locationServicesState == XWCLLocationServicesStateDisabled ||
        locationServicesState == XWCLLocationServicesStateDenied ||
        locationServicesState == XWCLLocationServicesStateRestricted) {
        // 无需添加此位置请求，因为位置服务已在设备范围内关闭，或者用户已拒绝此应用程序使用它们的权限
        [self completeLocationRequest:locationRequest];
        return;
    }
    
    switch (locationRequest.type) {
        case XWCLLocationRequestTypeSingle:
        case XWCLLocationRequestTypeSubscription:
        {
            XWCLLocationAccuracy maximumDesiredAccuracy = XWCLLocationAccuracyNone;
            // 确定所有现有位置请求的最大期望精度（不包括我们当前添加的新请求）
            for (XWCLLocationRequest *locationRequest in [self activeLocationRequestsExcludingType:XWCLLocationRequestTypeSignificantChanges]) {
                if (locationRequest.desiredAccuracy > maximumDesiredAccuracy) {
                    maximumDesiredAccuracy = locationRequest.desiredAccuracy;
                }
            }
            // 取所有现有位置请求的最大期望精度和我们当前添加的新请求的期望精度的最大值
            maximumDesiredAccuracy = MAX(locationRequest.desiredAccuracy, maximumDesiredAccuracy);
            [self updateWithMaximumDesiredAccuracy:maximumDesiredAccuracy];
            
            [self startUpdatingLocationIfNeeded];
        }
            break;
        case XWCLLocationRequestTypeSignificantChanges:
            [self startMonitoringSignificantLocationChangesIfNeeded];
            break;
    }
    __XWCL_GENERICS(NSMutableArray, XWCLLocationRequest *) *newLocationRequests = [NSMutableArray arrayWithArray:self.locationRequests];
    [newLocationRequests addObject:locationRequest];
    self.locationRequests = newLocationRequests;
    XWCLLMLog(@"Location Request added with ID: %ld", (long)locationRequest.requestID);
    
    // 现在处理所有位置请求，因为我们可能能够立即完成上面添加的请求
    // 如果最近收到满足其条件的位置更新（存储在self.currentLocation中）。
    [self processLocationRequests];
}

/**
 从请求数组中删除给定的位置请求，更新所需的最大精度，并在需要时停止位置更新。
 */
- (void)removeLocationRequest:(XWCLLocationRequest *)locationRequest
{
    __XWCL_GENERICS(NSMutableArray, XWCLLocationRequest *) *newLocationRequests = [NSMutableArray arrayWithArray:self.locationRequests];
    [newLocationRequests removeObject:locationRequest];
    self.locationRequests = newLocationRequests;
    
    switch (locationRequest.type) {
        case XWCLLocationRequestTypeSingle:
        case XWCLLocationRequestTypeSubscription:
        {
            // 确定所有剩余位置请求的最大期望精度
            XWCLLocationAccuracy maximumDesiredAccuracy = XWCLLocationAccuracyNone;
            for (XWCLLocationRequest *locationRequest in [self activeLocationRequestsExcludingType:XWCLLocationRequestTypeSignificantChanges]) {
                if (locationRequest.desiredAccuracy > maximumDesiredAccuracy) {
                    maximumDesiredAccuracy = locationRequest.desiredAccuracy;
                }
            }
            [self updateWithMaximumDesiredAccuracy:maximumDesiredAccuracy];
            
            [self stopUpdatingLocationIfPossible];
        }
            break;
        case XWCLLocationRequestTypeSignificantChanges:
            [self stopMonitoringSignificantLocationChangesIfPossible];
            break;
    }
}

/**
 返回最近的当前位置，如果当前位置未知、无效或过时，则返回nil。
 */
- (CLLocation *)currentLocation
{    
    if (_currentLocation) {
        // 位置不是空的，所以测试一下它是否有效
        if (!CLLocationCoordinate2DIsValid(_currentLocation.coordinate) || (_currentLocation.coordinate.latitude == 0.0 && _currentLocation.coordinate.longitude == 0.0)) {
            // 当前位置无效；丢弃它并返回nil
            _currentLocation = nil;
        }
    }
    
    // 此时位置为空或有效，返回它
    return _currentLocation;
}

/**
 请求在iOS 8+设备上使用位置服务的权限。
 */
- (void)requestAuthorizationIfNeeded
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_1
    // 从iOS 8开始，应用程序必须明确请求位置服务权限。XWCLLLocationManager支持“始终”和“使用时”两个级别。
    // XWCLLLocationManager根据应用程序的Info.plist中存在的描述键来确定请求的权限级别
    // 如果您为两个描述键都提供了值，则会请求更宽松的“始终”级别。
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1 && [CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        BOOL hasAlwaysKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"] != nil;
        BOOL hasWhenInUseKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"] != nil;
        if (hasAlwaysKey) {
            [self.locationManager requestAlwaysAuthorization];
        } else if (hasWhenInUseKey) {
            [self.locationManager requestWhenInUseAuthorization];
        } else {
            // 要在iOS 8+上使用位置服务，Info.plist文件中必须至少有一个密钥NSLocationAlwaysSageDescription或NSLocationWhenUseUsage Description。
            NSAssert(hasAlwaysKey || hasWhenInUseKey, @"To use location services in iOS 8+, your Info.plist must provide a value for either NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription.");
        }
    }
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_1 */
}

/**
 根据给定的最大期望精度（应该是所有活动位置请求的最大期望准确度）设置CLLocationManager期望准确度。
 */
- (void)updateWithMaximumDesiredAccuracy:(XWCLLocationAccuracy)maximumDesiredAccuracy
{
    switch (maximumDesiredAccuracy) {
        case XWCLLocationAccuracyNone:
            break;
        case XWCLLocationAccuracyCity:
            if (self.locationManager.desiredAccuracy != kCLLocationAccuracyThreeKilometers) {
                self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers;
                XWCLLMLog(@"Changing location services accuracy level to: low (minimum).");
            }
            break;
        case XWCLLocationAccuracyNeighborhood:
            if (self.locationManager.desiredAccuracy != kCLLocationAccuracyKilometer) {
                self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
                XWCLLMLog(@"Changing location services accuracy level to: medium low.");
            }
            break;
        case XWCLLocationAccuracyBlock:
            if (self.locationManager.desiredAccuracy != kCLLocationAccuracyHundredMeters) {
                self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
                XWCLLMLog(@"Changing location services accuracy level to: medium.");
            }
            break;
        case XWCLLocationAccuracyHouse:
            if (self.locationManager.desiredAccuracy != kCLLocationAccuracyNearestTenMeters) {
                self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
                XWCLLMLog(@"Changing location services accuracy level to: medium high.");
            }
            break;
        case XWCLLocationAccuracyRoom:
            if (self.locationManager.desiredAccuracy != kCLLocationAccuracyBest) {
                self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
                XWCLLMLog(@"Changing location services accuracy level to: high (maximum).");
            }
            break;
        default:
            NSAssert(nil, @"Invalid maximum desired accuracy!");
            break;
    }
}

/**
 通知CLLocationManager开始监控重大的位置变化。
 */
- (void)startMonitoringSignificantLocationChangesIfNeeded
{
    [self requestAuthorizationIfNeeded];
    
    NSArray *locationRequests = [self activeLocationRequestsWithType:XWCLLocationRequestTypeSignificantChanges];
    if (locationRequests.count == 0) {
        [self.locationManager startMonitoringSignificantLocationChanges];
        if (self.isMonitoringSignificantLocationChanges == NO) {
            XWCLLMLog(@"Significant location change monitoring has started.")
        }
        self.isMonitoringSignificantLocationChanges = YES;
    }
}

/**
 通知CLLocationManager开始向我们发送位置更新。
 */
- (void)startUpdatingLocationIfNeeded
{
    [self requestAuthorizationIfNeeded];
    
    NSArray *locationRequests = [self activeLocationRequestsExcludingType:XWCLLocationRequestTypeSignificantChanges];
    if (locationRequests.count == 0) {
        [self.locationManager startUpdatingLocation];
        if (self.isUpdatingLocation == NO) {
            XWCLLMLog(@"Location services updates have started.");
        }
        self.isUpdatingLocation = YES;
    }
}

- (void)stopMonitoringSignificantLocationChangesIfPossible
{
    NSArray *locationRequests = [self activeLocationRequestsWithType:XWCLLocationRequestTypeSignificantChanges];
    if (locationRequests.count == 0) {
        [self.locationManager stopMonitoringSignificantLocationChanges];
        if (self.isMonitoringSignificantLocationChanges) {
            XWCLLMLog(@"Significant location change monitoring has stopped.");
        }
        self.isMonitoringSignificantLocationChanges = NO;
    }
}

/**
 检查是否有任何未完成的定位请求，如果没有，则通知CLLocationManager停止发送位置更新。一旦不再需要位置更新，就会立即完成此操作，以节省设备的电池。
 */
- (void)stopUpdatingLocationIfPossible
{
    NSArray *locationRequests = [self activeLocationRequestsExcludingType:XWCLLocationRequestTypeSignificantChanges];
    if (locationRequests.count == 0) {
        [self.locationManager stopUpdatingLocation];
        if (self.isUpdatingLocation) {
            XWCLLMLog(@"Location services updates have stopped.");
        }
        self.isUpdatingLocation = NO;
    }
}

/**
 对活动位置请求数组进行迭代，以检查最近的当前位置是否成功满足其任何条件。
 */
- (void)processLocationRequests
{
    CLLocation *mostRecentLocation = self.currentLocation;
    
    for (XWCLLocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.hasTimedOut) {
            // 非经常性请求已超时，请完成它
            [self completeLocationRequest:locationRequest];
            continue;
        }
        
        if (mostRecentLocation != nil) {
            if (locationRequest.isRecurring) {
                // 这是一个订阅请求，它无限期存在（除非手动取消），并接收我们收到的每个位置更新
                [self processRecurringRequest:locationRequest];
                continue;
            } else {
                // 这是一个常规的一次性定位请求
                NSTimeInterval currentLocationTimeSinceUpdate = fabs([mostRecentLocation.timestamp timeIntervalSinceNow]);
                CLLocationAccuracy currentLocationHorizontalAccuracy = mostRecentLocation.horizontalAccuracy;
                NSTimeInterval staleThreshold = [locationRequest updateTimeStaleThreshold];
                CLLocationAccuracy horizontalAccuracyThreshold = [locationRequest horizontalAccuracyThreshold];
                if (currentLocationTimeSinceUpdate <= staleThreshold &&
                    currentLocationHorizontalAccuracy <= horizontalAccuracyThreshold) {
                    // 已达到请求所需的精度，请完成它
                    [self completeLocationRequest:locationRequest];
                    continue;
                }
            }
        }
    }
}

/**
 立即完成所有活动位置请求。用于位置服务授权状态更改为“拒绝”或“受限”等情况。
 */
- (void)completeAllLocationRequests
{
    // 迭代locationRequests数组的副本，以避免修改我们从中删除元素的同一数组
    __XWCL_GENERICS(NSArray, XWCLLocationRequest *) *locationRequests = [self.locationRequests copy];
    for (XWCLLocationRequest *locationRequest in locationRequests) {
        [self completeLocationRequest:locationRequest];
    }
    XWCLLMLog(@"Finished completing all location requests.");
}

/**
 通过从locationRequest数组中删除给定的位置请求并执行其完成块来完成该请求。
 */
- (void)completeLocationRequest:(XWCLLocationRequest *)locationRequest
{
    if (locationRequest == nil) {
        return;
    }
    
    [locationRequest complete];
    [self removeLocationRequest:locationRequest];
    
    XWCLLocationStatus status = [self statusForLocationRequest:locationRequest];
    CLLocation *currentLocation = self.currentLocation;
    XWCLLocationAccuracy achievedAccuracy = [self achievedAccuracyForLocation:currentLocation];
    
    // XWCLLLocationManager不是线程安全的，只能从主线程调用，因此我们现在应该已经在主线程上执行了。
    // dispatch_async用于确保在返回请求ID之前不会执行请求的完成块，
    // 例如在用户拒绝访问位置服务的权限并且请求立即完成并出现相应错误的情况下。
    dispatch_async(dispatch_get_main_queue(), ^{
        if (locationRequest.block) {
            locationRequest.block(currentLocation, achievedAccuracy, status);
        }
    });
    
    XWCLLMLog(@"Location Request completed with ID: %ld, currentLocation: %@, achievedAccuracy: %lu, status: %lu", (long)locationRequest.requestID, currentLocation, (unsigned long) achievedAccuracy, (unsigned long)status);
}

/**
 处理使用当前位置调用重复位置请求的块。
 */
- (void)processRecurringRequest:(XWCLLocationRequest *)locationRequest
{
    NSAssert(locationRequest.isRecurring, @"This method should only be called for recurring location requests.");
    
    XWCLLocationStatus status = [self statusForLocationRequest:locationRequest];
    CLLocation *currentLocation = self.currentLocation;
    XWCLLocationAccuracy achievedAccuracy = [self achievedAccuracyForLocation:currentLocation];
    
    // XWCLLLocationManager不是线程安全的，只能从主线程调用，因此我们现在应该已经在主线程上执行了。
    // dispatch_async用于确保在返回请求ID之前不会执行请求的完成块。
    dispatch_async(dispatch_get_main_queue(), ^{
        if (locationRequest.block) {
            locationRequest.block(currentLocation, achievedAccuracy, status);
        }
    });
}

/**
 返回给定类型的所有活动位置请求。
 */
- (NSArray *)activeLocationRequestsWithType:(XWCLLocationRequestType)locationRequestType
{
    return [self.locationRequests filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(XWCLLocationRequest *evaluatedObject, NSDictionary *bindings) {
        return evaluatedObject.type == locationRequestType;
    }]];
}

/**
 返回所有活动位置请求，不包括具有给定类型的请求。
 */
- (NSArray *)activeLocationRequestsExcludingType:(XWCLLocationRequestType)locationRequestType
{
    return [self.locationRequests filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(XWCLLocationRequest *evaluatedObject, NSDictionary *bindings) {
        return evaluatedObject.type != locationRequestType;
    }]];
}

/**
 返回给定位置请求的位置管理器状态。
 */
- (XWCLLocationStatus)statusForLocationRequest:(XWCLLocationRequest *)locationRequest
{
    XWCLLocationServicesState locationServicesState = [XWCLLocationManager locationServicesState];
    
    if (locationServicesState == XWCLLocationServicesStateDisabled) {
        return XWCLLocationStatusServicesDisabled;
    }
    else if (locationServicesState == XWCLLocationServicesStateNotDetermined) {
        return XWCLLocationStatusServicesNotDetermined;
    }
    else if (locationServicesState == XWCLLocationServicesStateDenied) {
        return XWCLLocationStatusServicesDenied;
    }
    else if (locationServicesState == XWCLLocationServicesStateRestricted) {
        return XWCLLocationStatusServicesRestricted;
    }
    else if (self.updateFailed) {
        return XWCLLocationStatusError;
    }
    else if (locationRequest.hasTimedOut) {
        return XWCLLocationStatusTimedOut;
    }
    
    return XWCLLocationStatusSuccess;
}

/**
 返回给定位置已达到的相关XWCLLocationAccuracy级别，
 基于该位置的水平精度和最近度。
 */
- (XWCLLocationAccuracy)achievedAccuracyForLocation:(CLLocation *)location
{
    if (!location) {
        return XWCLLocationAccuracyNone;
    }
    
    NSTimeInterval timeSinceUpdate = fabs([location.timestamp timeIntervalSinceNow]);
    CLLocationAccuracy horizontalAccuracy = location.horizontalAccuracy;
    
    if (horizontalAccuracy <= kXWCLHorizontalAccuracyThresholdRoom &&
        timeSinceUpdate <= kXWCLUpdateTimeStaleThresholdRoom) {
        return XWCLLocationAccuracyRoom;
    }
    else if (horizontalAccuracy <= kXWCLHorizontalAccuracyThresholdHouse &&
             timeSinceUpdate <= kXWCLUpdateTimeStaleThresholdHouse) {
        return XWCLLocationAccuracyHouse;
    }
    else if (horizontalAccuracy <= kXWCLHorizontalAccuracyThresholdBlock &&
             timeSinceUpdate <= kXWCLUpdateTimeStaleThresholdBlock) {
        return XWCLLocationAccuracyBlock;
    }
    else if (horizontalAccuracy <= kXWCLHorizontalAccuracyThresholdNeighborhood &&
             timeSinceUpdate <= kXWCLUpdateTimeStaleThresholdNeighborhood) {
        return XWCLLocationAccuracyNeighborhood;
    }
    else if (horizontalAccuracy <= kXWCLHorizontalAccuracyThresholdCity &&
             timeSinceUpdate <= kXWCLUpdateTimeStaleThresholdCity) {
        return XWCLLocationAccuracyCity;
    }
    else {
        return XWCLLocationAccuracyNone;
    }
}

#pragma mark Internal heading methods

/**
 返回最近的航向，如果当前航向未知或无效，则返回nil。
 */
- (CLHeading *)currentHeading
{
    // 航向不是空的，所以测试一下它是否有效
    if (!XWCLCLHeadingIsIsValid(_currentHeading)) {
        // 当前标题无效；丢弃它并返回nil
        _currentHeading = nil;
    }

    // 标题此时为空或有效，返回它
    return _currentHeading;
}

/**
 检查给定的CLHeading是否具有有效的属性。
 */
BOOL XWCLCLHeadingIsIsValid(CLHeading *heading)
{
    return heading.trueHeading > 0 &&
           heading.headingAccuracy > 0;
}

/**
 将给定的标题请求添加到请求数组中，并开始标题更新。
 */
- (void)addHeadingRequest:(XWCLHeadingRequest *)headingRequest
{
    NSAssert(headingRequest, @"Must pass in a non-nil heading request.");

    // 如果航向服务不可用，请返回
    if ([XWCLLocationManager headingServicesState] == XWCLHeadingServicesStateUnavailable) {
        // dispatch_async用于确保在返回请求ID之前不会执行请求的完成块。
        dispatch_async(dispatch_get_main_queue(), ^{
            if (headingRequest.block) {
                headingRequest.block(nil, XWCLHeadingStatusUnavailable);
            }
        });
        XWCLLMLog(@"Heading Request (ID %ld) NOT added since device heading is unavailable.", (long)headingRequest.requestID);
        return;
    }

    __XWCL_GENERICS(NSMutableArray, XWCLHeadingRequest *) *newHeadingRequests = [NSMutableArray arrayWithArray:self.headingRequests];
    [newHeadingRequests addObject:headingRequest];
    self.headingRequests = newHeadingRequests;
    XWCLLMLog(@"Heading Request added with ID: %ld", (long)headingRequest.requestID);

    [self startUpdatingHeadingIfNeeded];
}

/**
 通知CLLocationManager开始向我们发送航向更新。
 */
- (void)startUpdatingHeadingIfNeeded
{
    if (self.headingRequests.count != 0) {
        [self.locationManager startUpdatingHeading];
        if (self.isUpdatingHeading == NO) {
            XWCLLMLog(@"Heading services updates have started.");
        }
        self.isUpdatingHeading = YES;
    }
}

/**
 从请求数组中删除给定的标题请求，并在需要时停止标题更新。
 */
- (void)removeHeadingRequest:(XWCLHeadingRequest *)headingRequest
{
    __XWCL_GENERICS(NSMutableArray, XWCLHeadingRequest *) *newHeadingRequests = [NSMutableArray arrayWithArray:self.headingRequests];
    [newHeadingRequests removeObject:headingRequest];
    self.headingRequests = newHeadingRequests;

    [self stopUpdatingHeadingIfPossible];
}

/**
 检查是否有任何未完成的航向请求，如果没有，则通知CLLocationManager停止发送航向更新。一旦不再需要航向更新以节省设备的电池，就会进行此操作。
 */
- (void)stopUpdatingHeadingIfPossible
{
    if (self.headingRequests.count == 0) {
        [self.locationManager stopUpdatingHeading];
        if (self.isUpdatingHeading) {
            XWCLLMLog(@"Location services heading updates have stopped.");
        }
        self.isUpdatingHeading = NO;
    }
}

/**
 迭代活动标题请求数组，并处理每个请求
 */
- (void)processRecurringHeadingRequests
{
    for (XWCLHeadingRequest *headingRequest in self.headingRequests) {
        [self processRecurringHeadingRequest:headingRequest];
    }
}

/**
 处理使用当前航向调用重复航向请求的块。
 */
- (void)processRecurringHeadingRequest:(XWCLHeadingRequest *)headingRequest
{
    NSAssert(headingRequest.isRecurring, @"This method should only be called for recurring heading requests.");

    XWCLHeadingStatus status = [self statusForHeadingRequest:headingRequest];

    // 检查请求是否存在致命错误，是否应取消
    if (status == XWCLHeadingStatusUnavailable) {
        // dispatch_async用于确保在返回请求ID之前不会执行请求的完成块。
        dispatch_async(dispatch_get_main_queue(), ^{
            if (headingRequest.block) {
                headingRequest.block(nil, status);
            }
        });

        [self cancelHeadingRequest:headingRequest.requestID];
        return;
    }

    // dispatch_async用于确保在返回请求ID之前不会执行请求的完成块。
    dispatch_async(dispatch_get_main_queue(), ^{
        if (headingRequest.block) {
            headingRequest.block(self.currentHeading, status);
        }
    });
}

/**
 返回给定航向请求的状态。
 */
- (XWCLHeadingStatus)statusForHeadingRequest:(XWCLHeadingRequest *)headingRequest
{
    if ([XWCLLocationManager headingServicesState] == XWCLHeadingServicesStateUnavailable) {
        return XWCLHeadingStatusUnavailable;
    }

    // 对于无效的标题结果，访问者将返回nil
    if (!self.currentHeading) {
        return XWCLHeadingStatusInvalid;
    }

    return XWCLHeadingStatusSuccess;
}

#pragma mark XWCLLocationRequestDelegate method

- (void)locationRequestDidTimeout:(XWCLLocationRequest *)locationRequest
{
    // 为了增强稳健性，只有在位置请求仍然处于活动状态时才完成它（通过检查它是否尚未从locationRequests数组中删除）。
    for (XWCLLocationRequest *activeLocationRequest in self.locationRequests) {
        if (activeLocationRequest.requestID == locationRequest.requestID) {
            [self completeLocationRequest:locationRequest];
            break;
        }
    }
}

#pragma mark CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    // 已成功接收更新，请清除之前的所有错误
    self.updateFailed = NO;
    
    CLLocation *mostRecentLocation = [locations lastObject];
    self.currentLocation = mostRecentLocation;
    
    // 使用更新的位置处理位置请求
    [self processLocationRequests];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)newHeading
{
    self.currentHeading = newHeading;

    // 使用更新的航向处理标题请求
    [self processRecurringHeadingRequests];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    if (@available(iOS 14.0, *)) {
        if (manager.authorizationStatus == kCLAuthorizationStatusNotDetermined) {
            //iOS14 会在点击授权弹窗之前就回调这个方法，所以这里做个处理，保证授权之后可以继续进行定位请求
            return;
        }
    } else {
        // Fallback on earlier versions
    }
    
    XWCLLMLog(@"Location services error: %@", [error localizedDescription]);
    self.updateFailed = YES;

    for (XWCLLocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.isRecurring) {
            // 保持重复请求有效
            [self processRecurringRequest:locationRequest];
        } else {
            // 失败任何非经常性请求
            [self completeLocationRequest:locationRequest];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        // 清除所有活动的位置请求（这将执行状态反映位置服务不可用的块），因为我们现在不再有位置服务权限
        [self completeAllLocationRequests];
    }
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_1
    else if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
#else
    else if (status == kCLAuthorizationStatusAuthorized) {
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_1 */

        // 为等待授权的位置请求启动超时计时器
        for (XWCLLocationRequest *locationRequest in self.locationRequests) {
            [locationRequest startTimeoutTimerIfNeeded];
        }
    }
}
    
- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager {
    if (@available(iOS 14.0, *)) {
        CLAuthorizationStatus status = manager.authorizationStatus;
        if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
            // 清除所有活动的位置请求（这将执行状态反映位置服务不可用的块），因为我们现在不再有位置服务权限
            [self completeAllLocationRequests];
        }
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_1
        else if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
#else
            else if (status == kCLAuthorizationStatusAuthorized) {
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_1 */
                
            // 为等待授权的位置请求启动超时计时器
            for (XWCLLocationRequest *locationRequest in self.locationRequests) {
                [locationRequest startTimeoutTimerIfNeeded];
            }
        }
    } else {
        // Fallback on earlier versions
    }
}

@end
