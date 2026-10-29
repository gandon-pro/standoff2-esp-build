#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <cmath>
#include <cstring>
#include <cstdint>

// Runtime prototype: requires device verification and integration into the app.
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
 const void *find=nullptr,*camera=nullptr,*controller=nullptr,*transform=nullptr,*position=nullptr,*project=nullptr,*width=nullptr,*height=nullptr;
 bool ready=false;
 bool initialize() {
  if(!api.load())return false;
  player=api.cls("Axlebolt.Standoff.Gameplay.Player.dll","Axlebolt.Standoff.Gameplay.Player","PlayerBindings");
  auto object=api.cls("UnityEngine.CoreModule.dll","UnityEngine","Object");
  auto cam=api.cls("UnityEngine.CoreModule.dll","UnityEngine","Camera");
  auto component=api.cls("UnityEngine.CoreModule.dll","UnityEngine","Component");
  auto tr=api.cls("UnityEngine.CoreModule.dll","UnityEngine","Transform");
  auto type=api.cls("mscorlib.dll","System","Type");
  auto screen=api.cls("UnityEngine.CoreModule.dll","UnityEngine","Screen");
  width=api.method(screen,"get_width",0);height=api.method(screen,"get_height",0);
  find=api.method(object,"FindObjectsOfType",1,type);
  camera=api.method(cam,"get_main",0);
  controller=api.method(player,"get_CharacterController",0);
  transform=api.method(component,"get_transform",0);
  position=api.method(tr,"get_position",0);
  project=api.method(cam,"WorldToScreenPoint",1);
  return ready=player&&find&&camera&&controller&&transform&&position&&project&&width&&height;
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
} runtime;
}

@interface S2ESP : UIView
@property(nonatomic,strong) CAShapeLayer* boxes;
@property(nonatomic,strong) CADisplayLink* link;
@end
@implementation S2ESP
- (void)didMoveToWindow {
 [super didMoveToWindow];
 self.link.paused=self.window==nil;
}
- (instancetype)initWithFrame:(CGRect)frame {
 if((self=[super initWithFrame:frame])) {
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
 if(!runtime.ready&&!runtime.initialize())return;
 bool ok=false;void* cam=api.invoke(runtime.camera,nullptr,nullptr,ok);
 if(!ok||!cam)return;
 uint32_t cameraRoot=api.gchandle_new(cam,false);
 void* type=api.type_get_object(api.class_get_type(runtime.player));
 void* args[]={type};
 void* objects=api.invoke(runtime.find,nullptr,args,ok);
 if(!ok||!objects){api.gchandle_free(cameraRoot);return;}
 uint32_t arrayRoot=api.gchandle_new(objects,false);
 auto count=api.array_length(objects);
 int renderWidth=runtime.dimension(runtime.width),renderHeight=runtime.dimension(runtime.height);
 if(renderWidth<=0||renderHeight<=0){api.gchandle_free(arrayRoot);api.gchandle_free(cameraRoot);return;}
 CGFloat sx=self.bounds.size.width/renderWidth,sy=self.bounds.size.height/renderHeight;
 UIBezierPath* path=[UIBezierPath bezierPath];
 for(uintptr_t i=0;i<count&&i<128;i++) {
  objects=api.gchandle_get_target(arrayRoot);
  void* player=((void**)((char*)objects+api.array_object_header_size()))[i];
  auto cc=api.invoke(runtime.controller,player,nullptr,ok);if(!ok||!cc)continue;
  auto tr=api.invoke(runtime.transform,cc,nullptr,ok);if(!ok||!tr)continue;
  V3 foot,head,screenFoot,screenHead;
  if(!runtime.vector(runtime.position,tr,nullptr,foot))continue;
  head=foot;head.y+=1.7f;
  void* footArgs[]={&foot};void* headArgs[]={&head};
  cam=api.gchandle_get_target(cameraRoot);
  if(!runtime.vector(runtime.project,cam,footArgs,screenFoot)||
     !runtime.vector(runtime.project,cam,headArgs,screenHead)||screenFoot.z<=0.1f||screenHead.z<=0.1f)continue;
  CGFloat h=fabs(screenHead.y-screenFoot.y)*sy;
  if(h<2||h>self.bounds.size.height*2)continue;
  CGFloat x=screenHead.x*sx,y=self.bounds.size.height-screenHead.y*sy;
  [path appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(x-h*.25,y,h*.5,h)]];
 }
 api.gchandle_free(arrayRoot);api.gchandle_free(cameraRoot);
 self.boxes.path=path.CGPath;
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
 dispatch_async(dispatch_get_main_queue(),^{
  [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification
   object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification* notification) {
    InstallInActiveScene();
   }];
  InstallInActiveScene();
 });
}
