//
//  SMNRouteTable.h
//  ScanMyNet
//
//  Reads the one thing this SDK needs from the kernel routing table: the
//  address of the default route.
//
//  In Objective-C rather than Swift because <net/route.h> is not modularised in
//  the iOS SDK, so `struct rt_msghdr` and the RTAX_* constants are invisible to
//  Swift - while this framework already vendors route.h for MacFinder.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SMNRouteTable : NSObject

/// The IPv4 address of the default route, or nil when there is no default route
/// - an interface that is up but going nowhere.
+ (nullable NSString *)defaultGateway;

@end

NS_ASSUME_NONNULL_END
