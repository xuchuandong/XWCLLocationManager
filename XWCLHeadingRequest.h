//
//  XWCLHeadingRequest.h
//
//  Copyright (c) 2024 Xuanwu Inc.
//

#import "XWCLLocationDefines.h"

__XWCL_ASSUME_NONNULL_BEGIN

/// 航向请求
@interface XWCLHeadingRequest : NSObject

/** 航向请求的请求ID（初始化期间设置）。 */
@property (nonatomic, readonly) XWCLHeadingRequestID requestID;

/** 是否是一个重复的航向请求（目前假设所有航向请求都是）。 */
@property (nonatomic, readonly) BOOL isRecurring;

/** 航向请求完成要执行的块。 */
@property (nonatomic, copy, __XWCL_NULLABLE) XWCLHeadingRequestBlock block;

@end

__XWCL_ASSUME_NONNULL_END
