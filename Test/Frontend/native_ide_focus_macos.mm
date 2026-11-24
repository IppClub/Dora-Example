// Loaded into an ordinary Dora host to exercise its real Cocoa handoff method.
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import <objc/message.h>
#include <cstdlib>
struct lua_State;
@interface DoraFocusNativeInput : NSView
@end
@implementation DoraFocusNativeInput
- (BOOL)acceptsFirstResponder {return YES;}
@end
extern "C" int luaopen_native_ide_focus(lua_State *) {
 void(^test)(void)=^{@autoreleasepool {
  NSMutableDictionary *result=[@{@"success":@NO} mutableCopy];
  @try {
   Class cls=NSClassFromString(@"DoraIDEHost");if(!cls)@throw [NSException exceptionWithName:@"Test" reason:@"DoraIDEHost unavailable" userInfo:nil];
   NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,320,240) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
   window.releasedWhenClosed=NO;
   NSView *root=[[NSView alloc] initWithFrame:NSMakeRect(0,0,320,240)];window.contentView=root;
   Class webClass=NSClassFromString(@"DoraIDEWebView");if(!webClass)@throw [NSException exceptionWithName:@"Test" reason:@"DoraIDEWebView unavailable" userInfo:nil];
   WKWebView *web=[[webClass alloc] initWithFrame:root.bounds];[root addSubview:web];
   NSView *overlay=[[NSView alloc] initWithFrame:NSZeroRect];[root addSubview:overlay];
   id host=[[cls alloc] init];[host setValue:window forKey:@"window"];[host setValue:web forKey:@"view"];
   [host setValue:overlay forKey:@"overlay"];[host setValue:[[NSView alloc] init] forKey:@"menu"];
   [host setValue:@NO forKey:@"visible"];
   if(root.acceptsFirstResponder || ![window makeFirstResponder:web])@throw [NSException exceptionWithName:@"Test" reason:@"Invalid focus precondition" userInfo:nil];
   web.hidden=YES;
   auto collapse=[&]{((void(*)(id,SEL))objc_msgSend)(host,NSSelectorFromString(@"collapseMenu"));};
   collapse();
   if(window.firstResponder==web)@throw [NSException exceptionWithName:@"Test" reason:@"Hidden WebKit retained keyboard focus" userInfo:nil];
   result[@"hiddenWebKitReleased"]=@YES;
   [window makeFirstResponder:web];
   if(window.firstResponder==web || [web becomeFirstResponder])@throw [NSException exceptionWithName:@"Test" reason:@"Hidden WebKit stole focus asynchronously" userInfo:nil];
   result[@"hiddenWebKitCannotRegainFocus"]=@YES;
   DoraFocusNativeInput *late=[[DoraFocusNativeInput alloc] initWithFrame:NSZeroRect];[web addSubview:late];
   if(![window makeFirstResponder:late])@throw [NSException exceptionWithName:@"Test" reason:@"Late descendant focus precondition failed" userInfo:nil];
   ((void(*)(id,SEL))objc_msgSend)(host,NSSelectorFromString(@"focusEngine"));
   if(window.firstResponder==late)@throw [NSException exceptionWithName:@"Test" reason:@"Hidden WebKit descendant retained focus" userInfo:nil];
   result[@"lateWebKitDescendantReleased"]=@YES;
   DoraFocusNativeInput *native=[[DoraFocusNativeInput alloc] initWithFrame:NSZeroRect];[root addSubview:native];
   if(![window makeFirstResponder:native])@throw [NSException exceptionWithName:@"Test" reason:@"Native input could not focus" userInfo:nil];
   collapse();if(window.firstResponder!=native)@throw [NSException exceptionWithName:@"Test" reason:@"Native IME responder was displaced" userInfo:nil];
   result[@"nativeInputPreserved"]=@YES;
   web.hidden=NO;[host setValue:@YES forKey:@"visible"];collapse();
   if(window.firstResponder!=web)@throw [NSException exceptionWithName:@"Test" reason:@"Visible IDE did not regain focus" userInfo:nil];
   result[@"visibleIDERegainedFocus"]=@YES;result[@"success"]=@YES;
   [window makeFirstResponder:nil];[window close];
  } @catch(NSException *e) {result[@"error"]=e.reason?:@"Native focus test exception";}
  const char *output=getenv("DORA_NATIVE_IDE_FOCUS_OUTPUT");
  if(output)[[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[NSString stringWithUTF8String:output] atomically:YES];
 }};
 if(NSThread.isMainThread)test();else dispatch_sync(dispatch_get_main_queue(),test);return 0;
}
