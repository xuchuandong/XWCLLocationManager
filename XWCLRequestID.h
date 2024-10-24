//
//  XWCLRequestID.h
//
//  Copyright (c) 2024 XuanWu.
//

#import "XWCLLocationDefines.h"

__XWCL_ASSUME_NONNULL_BEGIN

@interface XWCLRequestID : NSObject

/**
 返回一个唯一的请求ID（在应用程序的生命周期内）。
 */
+(XWCLLocationRequestID)getUniqueRequestID;

@end

__XWCL_ASSUME_NONNULL_END
