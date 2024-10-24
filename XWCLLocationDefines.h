//
//  XWCLLocationDefines.h
//
//  Copyright (c) 2024 XuanWu.
//

#ifndef XWCL_LOCATION_REQUEST_DEFINES_H
#define XWCL_LOCATION_REQUEST_DEFINES_H

#import <CoreLocation/CoreLocation.h>

#if __has_feature(nullability)
#   define __XWCL_ASSUME_NONNULL_BEGIN      NS_ASSUME_NONNULL_BEGIN
#   define __XWCL_ASSUME_NONNULL_END        NS_ASSUME_NONNULL_END
#   define __XWCL_NULLABLE                  nullable
#else
#   define __XWCL_ASSUME_NONNULL_BEGIN
#   define __XWCL_ASSUME_NONNULL_END
#   define __XWCL_NULLABLE
#endif

#if __has_feature(objc_generics)
#   define __XWCL_GENERICS(type, ...)       type<__VA_ARGS__>
#else
#   define __XWCL_GENERICS(type, ...)       type
#endif

#ifdef NS_DESIGNATED_INITIALIZER
#   define __XWCL_DESIGNATED_INITIALIZER    NS_DESIGNATED_INITIALIZER
#else
#   define __XWCL_DESIGNATED_INITIALIZER
#endif

static const CLLocationAccuracy kXWCLHorizontalAccuracyThresholdCity =         5000.0;  // in meters
static const CLLocationAccuracy kXWCLHorizontalAccuracyThresholdNeighborhood = 1000.0;  // in meters
static const CLLocationAccuracy kXWCLHorizontalAccuracyThresholdBlock =         100.0;  // in meters
static const CLLocationAccuracy kXWCLHorizontalAccuracyThresholdHouse =          15.0;  // in meters
static const CLLocationAccuracy kXWCLHorizontalAccuracyThresholdRoom =            5.0;  // in meters

static const NSTimeInterval kXWCLUpdateTimeStaleThresholdCity =             600.0;  // in seconds
static const NSTimeInterval kXWCLUpdateTimeStaleThresholdNeighborhood =     300.0;  // in seconds
static const NSTimeInterval kXWCLUpdateTimeStaleThresholdBlock =             60.0;  // in seconds
static const NSTimeInterval kXWCLUpdateTimeStaleThresholdHouse =             15.0;  // in seconds
static const NSTimeInterval kXWCLUpdateTimeStaleThresholdRoom =               5.0;  // in seconds

/** 位置服务可能处于的状态。*/
typedef NS_ENUM(NSInteger, XWCLLocationServicesState) {
    /** 用户已授予此应用访问位置服务的权限，并且这些服务已启用并可供此应用使用。
     注意：对于“使用时”和“始终”权限级别，都将返回此状态。 */
    XWCLLocationServicesStateAvailable,
    /** 用户尚未响应授予此应用访问位置服务权限的对话框。 */
    XWCLLocationServicesStateNotDetermined,
    /** 用户已明确拒绝此应用程序访问位置服务的权限。（用户可以从系统设置应用程序再次启用此应用程序的权限。）*/
    XWCLLocationServicesStateDenied,
    /** 用户无法启用位置服务（例如家长控制、公司政策等）。 */
    XWCLLocationServicesStateRestricted,
    /** 用户已从系统设置应用程序关闭了设备范围内的位置服务（适用于所有应用程序）。*/
    XWCLLocationServicesStateDisabled
};

/** 航向服务可能处于的状态。*/
typedef NS_ENUM(NSInteger, XWCLHeadingServicesState) {
    /** 当前设备航向服务可用 */
    XWCLHeadingServicesStateAvailable,
    /** 当前设备航向服务不可用 */
    XWCLHeadingServicesStateUnavailable,
};

/** 位置请求唯一请求ID */
typedef NSInteger XWCLLocationRequestID;

/** 航向请求唯一请求ID */
typedef NSInteger XWCLHeadingRequestID;

/** 位置数据的水平精度和新近度的抽象。房间是最准确/最新的；城市是最低级别。*/
typedef NS_ENUM(NSInteger, XWCLLocationAccuracy) {
    // “无”作为所需的精度无效。
    /** 不准确（>5000米，和/或>10分钟前收到）。*/
    XWCLLocationAccuracyNone = 0,
    
    // 以下选项是有效的所需精度。
    /** 5000米或更高，并在最后10分钟内收到。精度最低。*/
    XWCLLocationAccuracyCity,
    /** 1000米或更高，并在最后5分钟内收到。*/
    XWCLLocationAccuracyNeighborhood,
    /** 100米或更高，并在最后1分钟内收到。*/
    XWCLLocationAccuracyBlock,
    /** 15米或更高，并在最后15秒内收到。*/
    XWCLLocationAccuracyHouse,
    /** 5米或更高，并在最后5秒内收到。最高精度。*/
    XWCLLocationAccuracyRoom,
};

/** 以度为单位的标题过滤器精度的别名。
 指定航向服务更新所需的最小度数变化量。如果更新小于规定的筛选值，则不会通知观察者。 */
typedef CLLocationDegrees XWCLHeadingFilterAccuracy;

/** 将传递到位置请求的完成块的状态。 */
typedef NS_ENUM(NSInteger, XWCLLocationStatus) {
    // 这些状态将伴随一个有效的位置。
    /** 成功获得了位置并达到了预期的精度水平。 */
    XWCLLocationStatusSuccess = 0,
    /** 已获取位置，但在超时之前未达到所需的精度级别。（不适用于订阅。） */
    XWCLLocationStatusTimedOut,
    
    // 这些状态表示某种错误，并将伴随着nil位置。
    /** 用户尚未响应授予此应用访问位置服务权限的对话框。*/
    XWCLLocationStatusServicesNotDetermined,
    /** 用户已明确拒绝此应用程序访问位置服务的权限。 */
    XWCLLocationStatusServicesDenied,
    /** 用户无法启用位置服务（例如家长控制、公司政策等）。*/
    XWCLLocationStatusServicesRestricted,
    /** 用户已从系统设置应用程序关闭了设备范围内的位置服务（适用于所有应用程序）。*/
    XWCLLocationStatusServicesDisabled,
    /** 使用系统位置服务时出错。*/
    XWCLLocationStatusError
};

/** 将传递到航向请求的完成块的状态。*/
typedef NS_ENUM(NSInteger, XWCLHeadingStatus) {
    // 这些状态将伴随一个有效的航向。
    /** 成功获得了一个航向。 */
    XWCLHeadingStatusSuccess = 0,

    // 这些状态表示某种错误，并将伴随一个空航向。
    /** 航向状态无效。 */
    XWCLHeadingStatusInvalid,

    /** 设备上没有航向服务 */
    XWCLHeadingStatusUnavailable
};

/**
 位置请求的块类型，当请求成功、失败或超时时执行。
 
 @param currentLocation 块执行时可用的最新准确当前位置，如果没有有效位置可用，则为nil。
 @param achievedAccuracy 实际达到的精度水平（可能优于、等于或低于所需的精度）。
 @param status 位置请求的状态-是成功、超时还是由于某种错误而失败。
             这可用于了解请求的结果，决定是否/如何使用关联的currentLocation，并确定是否需要其他操作
                （例如向用户显示错误消息、用另一个请求重试、悄悄继续等）。
 */
typedef void(^XWCLLocationRequestBlock)(CLLocation *currentLocation, XWCLLocationAccuracy achievedAccuracy, XWCLLocationStatus status);

/**
 航向请求的块类型，当请求成功时执行。

 @param currentHeading  块执行时可用的最新当前航向。
 @param status         请求的状态-它是成功还是由于某种错误而失败。这可用于了解是否需要采取任何进一步行动。
 */
typedef void(^XWCLHeadingRequestBlock)(CLHeading *currentHeading, XWCLHeadingStatus status);

#endif /* XWCL_LOCATION_REQUEST_DEFINES_H */
