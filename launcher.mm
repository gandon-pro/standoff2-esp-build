#import <Foundation/Foundation.h>
#import <mach-o/ldsyms.h>

@interface S2UnityFramework : NSObject
+ (instancetype)getInstance;
- (id)appController;
- (void)setExecuteHeader:(const struct mach_header*)header;
- (void)runUIApplicationMainWithArgc:(int)argc argv:(char*[])argv;
@end

int main(int argc, char* argv[]) {
 @autoreleasepool {
  NSString* path=[NSBundle.mainBundle.bundlePath stringByAppendingString:@"/Frameworks/UnityFramework.framework"];
  NSBundle* bundle=[NSBundle bundleWithPath:path];
  if(!bundle || (![bundle isLoaded] && ![bundle load]))return 1;
  Class frameworkClass=bundle.principalClass;
  if(!frameworkClass || ![frameworkClass respondsToSelector:@selector(getInstance)])return 2;
  S2UnityFramework* framework=[(id)frameworkClass getInstance];
  if(!framework)return 3;
  if(![framework appController])
   [framework setExecuteHeader:(const struct mach_header*)&_mh_execute_header];
  [framework runUIApplicationMainWithArgc:argc argv:argv];
 }
 return 0;
}
