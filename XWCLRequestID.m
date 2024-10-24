//
//  XWCLRequestID.m
//
//  Copyright (c) 2024 XuanWu.
//

#import "XWCLRequestID.h"

@implementation XWCLRequestID

static XWCLLocationRequestID _nextRequestID = 0;

+(XWCLLocationRequestID)getUniqueRequestID {
    _nextRequestID++;
    return _nextRequestID;
}

@end
