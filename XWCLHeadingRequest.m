//
//  XWCLHeadingRequest.m
//
//  Copyright (c) 2024 XuanWu.
//

#import "XWCLHeadingRequest.h"

#import "XWCLRequestID.h"

@implementation XWCLHeadingRequest

/**
 指定初始化。初始化并返回新分配的航向请求。
 */
- (instancetype)init
{
    if (self = [super init]) {
        _requestID = [XWCLRequestID getUniqueRequestID];
        _isRecurring = YES;
    }
    return self;
}

/**
 如果两个航向请求的请求ID匹配，则认为它们相等。
 */
- (BOOL)isEqual:(id)object
{
    if (object == self) {
        return YES;
    }
    if (!object || ![object isKindOfClass:[self class]]) {
        return NO;
    }
    if (((XWCLHeadingRequest *)object).requestID == self.requestID) {
        return YES;
    }
    return NO;
}

/**
 根据请求ID的字符串返回哈希值。
 */
- (NSUInteger)hash {
    return [[NSString stringWithFormat:@"%ld", (long)self.requestID] hash];
}

@end
