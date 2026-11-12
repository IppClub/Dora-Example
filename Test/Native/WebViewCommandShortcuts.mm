#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include "SDL.h"
#include "SDL_syswm.h"
#include "WebViewShortcutProduction.inc"
static void pump(double seconds) {
 NSDate* end=[NSDate dateWithTimeIntervalSinceNow:seconds];
 while(end.timeIntervalSinceNow>0){SDL_PumpEvents();[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.005]];}
}
static id js(WKWebView* view, NSString* script) {
 __block BOOL done=NO;__block id value;__block NSError* failure;
 [view evaluateJavaScript:script completionHandler:^(id result,NSError* error){value=result;failure=error;done=YES;}];
 NSDate* deadline=[NSDate dateWithTimeIntervalSinceNow:5];while(!done && deadline.timeIntervalSinceNow>0)pump(.01);
 if(!done || failure){NSLog(@"JavaScript fixture failed: %@",failure);@throw [NSException exceptionWithName:@"FixtureFailure" reason:@"JavaScript fixture failed" userInfo:nil];}return value;
}
static void check(BOOL result,NSString* name){if(!result){NSLog(@"FAIL: %@",name);@throw [NSException exceptionWithName:@"FixtureFailure" reason:name userInfo:nil];}NSLog(@"PASS: %@",name);}
static void expectJS(WKWebView* view,NSString* condition,NSString* name){
 NSDate* deadline=[NSDate dateWithTimeIntervalSinceNow:5];
 while(![js(view,condition) boolValue] && deadline.timeIntervalSinceNow>0)pump(.02);
 check([js(view,condition) boolValue],name);
}
static void expectClipboard(NSPasteboard* clipboard,NSString* text,NSString* name){
 NSDate* deadline=[NSDate dateWithTimeIntervalSinceNow:5];
 while(![[clipboard stringForType:NSPasteboardTypeString] isEqualToString:text] && deadline.timeIntervalSinceNow>0)pump(.02);
 check([[clipboard stringForType:NSPasteboardTypeString] isEqualToString:text],name);
}
static void press(NSWindow* window,NSString* key,unsigned short code,NSEventModifierFlags flags=NSEventModifierFlagCommand) {
 [NSApp activateIgnoringOtherApps:YES];[window makeKeyAndOrderFront:nil];pump(.05);
 for(NSNumber* up in @[@NO,@YES]){
  NSEvent* event=[NSEvent keyEventWithType:up.boolValue?NSEventTypeKeyUp:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:flags timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window.windowNumber context:nil characters:key charactersIgnoringModifiers:key isARepeat:NO keyCode:code];
  [NSApp postEvent:event atStart:NO];pump(.3);
 }
}
int main(int argc,char** argv){@autoreleasepool{
 if(argc<2)return 2;
 // Restore clipboard without logging or writing its previous contents to disk.
 NSPasteboard* clipboard=NSPasteboard.generalPasteboard;NSMutableArray* saved=[NSMutableArray array];
 for(NSPasteboardItem* item in clipboard.pasteboardItems){NSPasteboardItem* copy=[NSPasteboardItem new];for(NSPasteboardType type in item.types){NSData* data=[item dataForType:type];if(data)[copy setData:data forType:type];}[saved addObject:copy];}
 @try {
 SDL_SetMainReady();check(SDL_Init(SDL_INIT_VIDEO)==0,@"SDL video startup");
 SDL_Window* sdl=SDL_CreateWindow("Dora WebView shortcut regression",100,100,800,650,SDL_WINDOW_SHOWN);
 SDL_SysWMinfo info{};SDL_VERSION(&info.version);SDL_GetWindowWMInfo(sdl,&info);NSWindow* window=info.info.cocoa.window;
 DoraIDEHost* host=[DoraIDEHost new];host.window=window;host.visible=YES;
 WKWebViewConfiguration* config=[WKWebViewConfiguration new];
 [config.userContentController addScriptMessageHandler:host name:@"doraIDEEdit"];
 if(!getenv("DORA_SHORTCUT_BASELINE"))[config.userContentController addUserScript:[[WKUserScript alloc]initWithSource:ideEditingShortcutScript() injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES]];
 WKWebView* view=[[DoraIDEWebView alloc]initWithFrame:window.contentView.bounds configuration:config];view.identifier=@"DoraNativeUI";host.view=view;[window.contentView addSubview:view];
 BOOL zh=NO;installEditMenu(zh);
 id pasteMonitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent*(NSEvent* event){return host.visible && idePasteKeyEquivalent(view,event)?nil:event;}];
 [view loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@(argv[1])]]];pump(1);
 NSDate* deadline=[NSDate dateWithTimeIntervalSinceNow:15];while(![js(view,@"!!window.editor") boolValue] && deadline.timeIntervalSinceNow>0)pump(.1);
 expectJS(view,@"!!window.editor",@"real Monaco loaded in WKWebView");
 [NSApp activateIgnoringOtherApps:YES];[window makeKeyAndOrderFront:nil];[window makeFirstResponder:view];js(view,@"t.focus();t.value='hello';t.setSelectionRange(0,0)");pump(.1);
 if(!getenv("DORA_CLIPBOARD_ONLY")){
 press(window,@"a",0);expectJS(view,@"t.selectionStart===0 && t.selectionEnd===5",@"Command+A selects input text");
 press(window,@"c",8);expectClipboard(clipboard,@"hello",@"Command+C copies input text");
 press(window,@"x",7);expectJS(view,@"t.value===''",@"Command+X cuts input text");
 press(window,@"v",9);expectJS(view,@"t.value==='hello'",@"Command+V pastes input text");
 press(window,@"z",6);expectJS(view,@"t.value===''",@"Command+Z undoes paste");
 press(window,@"z",6,NSEventModifierFlagCommand|NSEventModifierFlagShift);expectJS(view,@"t.value==='hello'",@"Command+Shift+Z redoes paste");
 js(view,@"window.saves=0;window.savesShift=0;window.finds=0");press(window,@"s",1);press(window,@"s",1,NSEventModifierFlagCommand|NSEventModifierFlagShift);press(window,@"f",3);
 expectJS(view,@"saves===1 && savesShift===1 && finds===1",@"save/save-all/find receive trusted DOM events once");
 js(view,@"window.prevented=0;t.value='hello';t.setSelectionRange(0,0);window.block=e=>{if(e.metaKey&&e.key==='a'){prevented++;e.preventDefault();}};document.addEventListener('keydown',block)");
 press(window,@"a",0);expectJS(view,@"prevented===1 && t.selectionEnd===0",@"page-prevented editing is not overridden");js(view,@"document.removeEventListener('keydown',block)");
 js(view,@"t.dispatchEvent(new KeyboardEvent('keydown',{key:'a',metaKey:true,bubbles:true,cancelable:true}))");pump(.1);expectJS(view,@"t.selectionEnd===0",@"synthetic DOM events cannot trigger native editing");
 js(view,@"t.dispatchEvent(new KeyboardEvent('keydown',{key:'a',metaKey:true,isComposing:true,bubbles:true,cancelable:true}))");pump(.1);expectJS(view,@"t.selectionEnd===0",@"composition events are ignored");
 host.visible=NO;press(window,@"a",0);expectJS(view,@"t.selectionEnd===0",@"hidden IDE cannot perform native edit actions");host.visible=YES;
 }
 // Native clipboard image data must reach the composer's standard paste event.
 js(view,@"window.pasteFiles=[];window.pasteCount=0;window.capturePaste=e=>{pasteCount++;pasteFiles=Array.from(e.clipboardData.files).map(f=>({name:f.name,type:f.type,size:f.size}));e.preventDefault();};t.addEventListener('paste',capturePaste);t.focus()");
 [clipboard clearContents];[clipboard setData:[[NSData alloc]initWithBase64EncodedString:@"iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC" options:0] forType:NSPasteboardTypePNG];
 press(window,@"v",9);expectJS(view,@"pasteFiles.length===1 && pasteFiles[0].type==='image/png'",@"Command+V exposes clipboard PNG as a File");
 expectJS(view,@"pasteCount===1",@"Command+V pastes the image once");
 [NSApp sendAction:@selector(paste:) to:nil from:view];pump(.5);
 expectJS(view,@"pasteCount===2 && pasteFiles[0].type==='image/png'",@"native menu and Command+V expose equivalent PNG files");
 if(argc>2){
  NSURL* fileURL=[NSURL fileURLWithPath:@(argv[2])];[clipboard clearContents];[clipboard writeObjects:@[fileURL]];
  js(view,@"pasteFiles=[];pasteCount=0");press(window,@"v",9);expectJS(view,@"pasteFiles.length===1 && /image\\/(png|jpeg)/.test(pasteFiles[0].type)",@"Finder image file paste exposes a supported File");expectJS(view,@"pasteCount===1",@"Finder image is pasted once");
 }
 if(argc>3){
  [clipboard clearContents];[clipboard writeObjects:@[[NSURL fileURLWithPath:@(argv[3])]]];
  js(view,@"pasteFiles=[];pasteCount=0");press(window,@"v",9);
  expectJS(view,@"pasteCount===1 && pasteFiles.length===1 && pasteFiles[0].name==='clipboard-document.txt' && pasteFiles[0].size>0",@"Command+V exposes a Finder non-image file once");
 }
 js(view,@"t.removeEventListener('paste',capturePaste)");
 if(!getenv("DORA_CLIPBOARD_ONLY")){
 js(view,@"editor.focus();editor.setPosition({lineNumber:1,column:1})");pump(.1);press(window,@"a",0);
 expectJS(view,@"editor.getSelection().endLineNumber===3 && editor.getSelection().endColumn===6",@"Monaco Command+A selects the complete model");
 press(window,@"c",8);expectClipboard(clipboard,@"first\nsecond\nthird",@"Monaco Command+C keeps its editor clipboard behavior");
 // Real typing and undo/redo must affect Monaco's model, not its hidden textarea.
 press(window,@"k",40,0);expectJS(view,@"editor.getValue()==='k'",@"Monaco typing replaces selected model");
 press(window,@"z",6);expectJS(view,@"editor.getValue()==='first\\nsecond\\nthird'",@"Monaco Command+Z uses editor undo");
 press(window,@"z",6,NSEventModifierFlagCommand|NSEventModifierFlagShift);expectJS(view,@"editor.getValue()==='k'",@"Monaco Command+Shift+Z uses editor redo");
 }
 [NSEvent removeMonitor:pasteMonitor];
 [config.userContentController removeScriptMessageHandlerForName:@"doraIDEEdit"];[window orderOut:nil];SDL_DestroyWindow(sdl);SDL_Quit();
 } @catch(NSException* error) {NSLog(@"Regression failed: %@",error.reason);return 1;} @finally {[clipboard clearContents];[clipboard writeObjects:saved];}
}return 0;}
