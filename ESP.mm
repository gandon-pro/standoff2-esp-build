#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <cmath>
#include <cstring>
#include <cstdint>
#include <cstdio>
#include <ctime>

static void S2Log(const char* state, unsigned long found=0, unsigned long drawn=0) {
 NSString* path=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/S2ESP-diagnostics.log"];
 FILE* file=fopen(path.fileSystemRepresentation,"a+");
 if(!file)return;
 if(fseek(file,0,SEEK_END)==0 && ftell(file)>256*1024) {
  fclose(file);
  file=fopen(path.fileSystemRepresentation,"w");
  if(!file)return;
 }
 fprintf(file,"%lld %s found=%lu drawn=%lu\n",(long long)time(nullptr),state,found,drawn);
 fclose(file);
}

// Runtime prototype: requires device verification.
namespace {
struct V3 { float x,y,z; };
struct API {
 void* (*domain_get)();
 void* (*domain_assembly_open)(void*,const char*);
 void* (*assembly_get_image)(void*);
 void* (*class_from_name)(void*,const char*,const char*);
 const void* (*class_get_methods)(void*,void**);
 const char* (*method_get_name)(const void*);
 unsigned (*method_get_param_count)(const void*);
 const void* (*method_get_param)(const void*,unsigned);
 void* (*type_get_class_or_element_class)(const void*);
 const void* (*class_get_type)(void*);
 void* (*type_get_object)(const void*);
 void* (*runtime_invoke)(const void*,void*,void**,void**);
 void* (*object_unbox)(void*);
 uintptr_t (*array_length)(void*);
 unsigned (*array_object_header_size)();
 uint32_t (*gchandle_new)(void*,bool);
 void (*gchandle_free)(uint32_t);
 void* (*gchandle_get_target)(uint32_t);
 void* handle=nullptr;
 bool load() {
  handle=RTLD_DEFAULT;
#define LOAD(n) n=reinterpret_cast<decltype(n)>(dlsym(handle,"il2cpp_" #n)); if(!n) return false
  LOAD(domain_get); LOAD(domain_assembly_open); LOAD(assembly_get_image);
  LOAD(class_from_name); LOAD(class_get_methods); LOAD(method_get_name);
  LOAD(method_get_param_count); LOAD(method_get_param);
  LOAD(type_get_class_or_element_class); LOAD(class_get_type); LOAD(type_get_object);
  LOAD(runtime_invoke); LOAD(object_unbox); LOAD(array_length); LOAD(array_object_header_size);
  LOAD(gchandle_new); LOAD(gchandle_free); LOAD(gchandle_get_target);
#undef LOAD
  return domain_get()!=nullptr;
 }
 void* cls(const char* image,const char* ns,const char* name) {
  auto assembly=domain_assembly_open(domain_get(),image);
  return assembly?class_from_name(assembly_get_image(assembly),ns,name):nullptr;
 }
 const void* method(void* cls,const char* name,unsigned argc,void* firstType=nullptr) {
  if(!cls)return nullptr;
  void* iter=nullptr;
  while(auto m=class_get_methods(cls,&iter))
   if(!strcmp(method_get_name(m),name) && method_get_param_count(m)==argc &&
      (!firstType || type_get_class_or_element_class(method_get_param(m,0))==firstType))return m;
  return nullptr;
 }
 void* invoke(const void* method,void* object,void** args,bool& ok) {
  if(!method){ok=false;return nullptr;}
  void* exception=nullptr;
  auto result=runtime_invoke(method,object,args,&exception);
  ok=exception==nullptr;
  return result;
 }
} api;
struct Runtime {
 void* player=nullptr;
 const void *find=nullptr,*camera=nullptr,*controller=nullptr,*transform=nullptr,*transformPoint=nullptr,*project=nullptr,*width=nullptr,*height=nullptr;
 const void *capsuleHeight=nullptr,*capsuleCenter=nullptr;
 bool ready=false;
 bool initialize() {
  if(!api.load())return false;
  player=api.cls("Axlebolt.Standoff.Gameplay.Player.dll","Axlebolt.Standoff.Gameplay.Player","PlayerBindings");
  auto object=api.cls("UnityEngine.CoreModule.dll","UnityEngine","Object");
  auto cam=api.cls("UnityEngine.CoreModule.dll","UnityEngine","Camera");
  auto component=api.cls("UnityEngine.CoreModule.dll","UnityEngine","Component");
  auto character=api.cls("UnityEngine.PhysicsModule.dll","UnityEngine","CharacterController");
  auto tr=api.cls("UnityEngine.CoreModule.dll","UnityEngine","Transform");
  auto type=api.cls("mscorlib.dll","System","Type");
  auto screen=api.cls("UnityEngine.CoreModule.dll","UnityEngine","Screen");
  width=api.method(screen,"get_width",0);height=api.method(screen,"get_height",0);
  find=api.method(object,"FindObjectsOfType",1,type);
  camera=api.method(cam,"get_main",0);
  controller=api.method(player,"get_CharacterController",0);
  capsuleHeight=api.method(character,"get_height",0);
  capsuleCenter=api.method(character,"get_center",0);
  transform=api.method(component,"get_transform",0);
  transformPoint=api.method(tr,"TransformPoint",1);
  project=api.method(cam,"WorldToScreenPoint",1);
  return ready=player&&find&&camera&&controller&&capsuleHeight&&capsuleCenter&&transform&&transformPoint&&project&&width&&height;
 }
 bool vector(const void* m,void* obj,void** args,V3& out) {
  bool ok;auto boxed=api.invoke(m,obj,args,ok);
  if(!ok||!boxed)return false;
  memcpy(&out,api.object_unbox(boxed),sizeof(out));
  return std::isfinite(out.x)&&std::isfinite(out.y)&&std::isfinite(out.z);
 }
 int dimension(const void* method) {
  bool ok;void* boxed=api.invoke(method,nullptr,nullptr,ok);
  if(!ok||!boxed)return 0;
  int value;memcpy(&value,api.object_unbox(boxed),sizeof(value));return value;
 }
 bool scalar(const void* method,void* object,float& out) {
  bool ok;void* boxed=api.invoke(method,object,nullptr,ok);
  if(!ok||!boxed)return false;
  memcpy(&out,api.object_unbox(boxed),sizeof(out));
  return std::isfinite(out);
 }
} runtime;
}

@interface S2ESP : UIView
@property(nonatomic,strong) CAShapeLayer* boxes;
@property(nonatomic,strong) CADisplayLink* link;
@end
@implementation S2ESP
{
 char _lastState[32];
 CFTimeInterval _lastSummary;
}
- (void)report:(const char*)state found:(NSUInteger)found drawn:(NSUInteger)drawn {
 CFTimeInterval now=CACurrentMediaTime();
 if(strcmp(_lastState,state)!=0 || now-_lastSummary>=15) {
  S2Log(state,(unsigned long)found,(unsigned long)drawn);
  snprintf(_lastState,sizeof(_lastState),"%s",state);
  _lastSummary=now;
 }
}
- (void)didMoveToWindow {
 [super didMoveToWindow];
 self.link.paused=self.window==nil;
}
- (instancetype)initWithFrame:(CGRect)frame {
 if((self=[super initWithFrame:frame])) {
  _lastState[0]=0;
  self.userInteractionEnabled=NO;self.backgroundColor=UIColor.clearColor;
  _boxes=[CAShapeLayer layer];_boxes.strokeColor=UIColor.greenColor.CGColor;
  _boxes.fillColor=UIColor.clearColor.CGColor;_boxes.lineWidth=1.5;
  [self.layer addSublayer:_boxes];
  _link=[CADisplayLink displayLinkWithTarget:self selector:@selector(updateESP)];
  _link.preferredFramesPerSecond=20;
  [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
 }
 return self;
}
- (void)updateESP {
 self.boxes.path=nil;
 if(!runtime.ready&&!runtime.initialize()){
  [self report:"runtime_unavailable" found:0 drawn:0];return;
 }
 bool ok=false;void* cam=api.invoke(runtime.camera,nullptr,nullptr,ok);
 if(!ok||!cam){[self report:"camera_unavailable" found:0 drawn:0];return;}
 uint32_t cameraRoot=api.gchandle_new(cam,false);
 void* type=api.type_get_object(api.class_get_type(runtime.player));
 void* args[]={type};
 void* objects=api.invoke(runtime.find,nullptr,args,ok);
 if(!ok||!objects){api.gchandle_free(cameraRoot);[self report:"player_query_failed" found:0 drawn:0];return;}
 uint32_t arrayRoot=api.gchandle_new(objects,false);
 auto count=api.array_length(objects);
 int renderWidth=runtime.dimension(runtime.width),renderHeight=runtime.dimension(runtime.height);
 if(renderWidth<=0||renderHeight<=0){api.gchandle_free(arrayRoot);api.gchandle_free(cameraRoot);[self report:"screen_unavailable" found:count drawn:0];return;}
 CGFloat sx=self.bounds.size.width/renderWidth,sy=self.bounds.size.height/renderHeight;
 UIBezierPath* path=[UIBezierPath bezierPath];
 NSUInteger drawn=0;
 for(uintptr_t i=0;i<count&&i<128;i++) {
  objects=api.gchandle_get_target(arrayRoot);
  void* player=((void**)((char*)objects+api.array_object_header_size()))[i];
  auto cc=api.invoke(runtime.controller,player,nullptr,ok);if(!ok||!cc)continue;
  auto tr=api.invoke(runtime.transform,cc,nullptr,ok);if(!ok||!tr)continue;
  V3 foot,head,center,screenFoot,screenHead;
  float capsuleHeight;
  if(!runtime.vector(runtime.capsuleCenter,cc,nullptr,center)||
     !runtime.scalar(runtime.capsuleHeight,cc,capsuleHeight)||
     capsuleHeight<0.3f||capsuleHeight>3.5f)continue;
  V3 localFoot=center,localHead=center;
  localFoot.y-=capsuleHeight*.5f;
  localHead.y+=capsuleHeight*.5f;
  void* localFootArgs[]={&localFoot};void* localHeadArgs[]={&localHead};
  if(!runtime.vector(runtime.transformPoint,tr,localFootArgs,foot)||
     !runtime.vector(runtime.transformPoint,tr,localHeadArgs,head))continue;
  void* footArgs[]={&foot};void* headArgs[]={&head};
  cam=api.gchandle_get_target(cameraRoot);
  if(!runtime.vector(runtime.project,cam,footArgs,screenFoot)||
     !runtime.vector(runtime.project,cam,headArgs,screenHead)||screenFoot.z<=0.1f||screenHead.z<=0.1f)continue;
  CGFloat h=fabs(screenHead.y-screenFoot.y)*sy;
  if(h<2||h>self.bounds.size.height*2)continue;
  CGFloat x=screenHead.x*sx,y=self.bounds.size.height-screenHead.y*sy;
  [path appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(x-h*.25,y,h*.5,h)]];
  ++drawn;
 }
 api.gchandle_free(arrayRoot);api.gchandle_free(cameraRoot);
 self.boxes.path=path.CGPath;
 [self report:(drawn?"drawing":"no_visible_targets") found:count drawn:drawn];
}
@end

extern "C" __attribute__((visibility("default"))) void S2ESPInstall(UIWindow* window) {
 dispatch_async(dispatch_get_main_queue(),^{
  if(!window)return;
  for(UIView* existing in window.subviews)
   if([existing isKindOfClass:S2ESP.class])return;
  S2ESP* view=[[S2ESP alloc] initWithFrame:window.bounds];
  view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
  [window addSubview:view];
  S2Log("overlay_installed");
 });
}

static void InstallInActiveScene() {
 UIApplication* app=UIApplication.sharedApplication;
 if(app.applicationState!=UIApplicationStateActive)return;
 for(UIScene* scene in app.connectedScenes) {
  if(scene.activationState!=UISceneActivationStateForegroundActive||
     ![scene isKindOfClass:UIWindowScene.class])continue;
  for(UIWindow* window in ((UIWindowScene*)scene).windows)
   if(window.isKeyWindow&&!window.hidden&&window.rootViewController) {
    S2ESPInstall(window);return;
   }
 }
}

__attribute__((constructor)) static void S2ESPStart() {
 S2Log("library_loaded");
 dispatch_async(dispatch_get_main_queue(),^{
  [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification
   object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification* notification) {
    InstallInActiveScene();
   }];
  InstallInActiveScene();
 });
}
