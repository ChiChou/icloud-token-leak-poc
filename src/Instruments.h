#import <Foundation/Foundation.h>

#include "InstrumentsPlugin.h"

@interface Instruments : NSObject
- (NSArray *)devices;
- (NSString *)leakDevice:(XRRemoteDevice *)device to:(NSString *)path;
// - (void)warmupForDevice:(XRRemoteDevice *)device;
@end

