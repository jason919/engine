// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "flutter/shell/platform/darwin/common/framework/Headers/FlutterBinaryMessenger.h"
#import "flutter/shell/platform/darwin/common/framework/Headers/FlutterMacros.h"
#import "flutter/shell/platform/darwin/ios/framework/Headers/FlutterPlatformViews.h"
#import "flutter/shell/platform/darwin/ios/framework/Headers/FlutterViewController.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterPlatformViews_Internal.h"
#import "flutter/shell/platform/darwin/ios/framework/Source/FlutterViewController_Internal.h"
#import "flutter/shell/platform/darwin/ios/platform_view_ios.h"

FLUTTER_ASSERT_NOT_ARC
@class FlutterPlatformViewsTestMockPlatformView;
static FlutterPlatformViewsTestMockPlatformView* gMockPlatformView = nil;
const float kFloatCompareEpsilon = 0.001;

@interface FlutterPlatformViewsTestMockPlatformView : UIView
@end
@implementation FlutterPlatformViewsTestMockPlatformView

- (instancetype)init {
  self = [super init];
  if (self) {
    gMockPlatformView = self;
  }
  return self;
}

- (void)dealloc {
  gMockPlatformView = nil;
  [super dealloc];
}

@end

@interface FlutterPlatformViewsTestMockFlutterPlatformView : NSObject <FlutterPlatformView>
@property(nonatomic, strong) UIView* view;
@property(nonatomic, assign) BOOL viewCreated;
@end

@implementation FlutterPlatformViewsTestMockFlutterPlatformView

- (instancetype)init {
  if (self = [super init]) {
    _view = [[FlutterPlatformViewsTestMockPlatformView alloc] init];
    _viewCreated = NO;
  }
  return self;
}

- (UIView*)view {
  [self checkViewCreatedOnce];
  return _view;
}

- (void)checkViewCreatedOnce {
  if (self.viewCreated) {
    abort();
  }
  self.viewCreated = YES;
}

- (void)dealloc {
  [_view release];
  _view = nil;
  [super dealloc];
}

@end

@interface FlutterPlatformViewsTestMockFlutterPlatformFactory
    : NSObject <FlutterPlatformViewFactory>
@end

@implementation FlutterPlatformViewsTestMockFlutterPlatformFactory
- (NSObject<FlutterPlatformView>*)createWithFrame:(CGRect)frame
                                   viewIdentifier:(int64_t)viewId
                                        arguments:(id _Nullable)args {
  return [[[FlutterPlatformViewsTestMockFlutterPlatformView alloc] init] autorelease];
}

@end

namespace flutter {
namespace {
class FlutterPlatformViewsTestMockPlatformViewDelegate : public PlatformView::Delegate {
  void OnPlatformViewCreated(std::unique_ptr<Surface> surface) override {}
  void OnPlatformViewDestroyed() override {}
  void OnPlatformViewSetNextFrameCallback(const fml::closure& closure) override {}
  void OnPlatformViewSetViewportMetrics(const ViewportMetrics& metrics) override {}
  void OnPlatformViewDispatchPlatformMessage(fml::RefPtr<PlatformMessage> message) override {}
  void OnPlatformViewDispatchPointerDataPacket(std::unique_ptr<PointerDataPacket> packet) override {
  }
  void OnPlatformViewDispatchSemanticsAction(int32_t id,
                                             SemanticsAction action,
                                             std::vector<uint8_t> args) override {}
  void OnPlatformViewSetSemanticsEnabled(bool enabled) override {}
  void OnPlatformViewSetAccessibilityFeatures(int32_t flags) override {}
  void OnPlatformViewRegisterTexture(std::shared_ptr<Texture> texture) override {}
  void OnPlatformViewUnregisterTexture(int64_t texture_id) override {}
  void OnPlatformViewMarkTextureFrameAvailable(int64_t texture_id) override {}

  void LoadDartDeferredLibrary(intptr_t loading_unit_id,
                               const uint8_t* snapshot_data,
                               const uint8_t* snapshot_instructions) override {}
  void UpdateAssetManager(std::shared_ptr<AssetManager> asset_manager) override {}
};

}  // namespace
}  // namespace flutter

namespace {
fml::RefPtr<fml::TaskRunner> CreateNewThread(std::string name) {
  auto thread = std::make_unique<fml::Thread>(name);
  auto runner = thread->GetTaskRunner();
  return runner;
}
}  // namespace

@interface FlutterPlatformViewsTest : XCTestCase
@end

@implementation FlutterPlatformViewsTest

- (void)testFlutterViewOnlyCreateOnceInOneFrame {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread_task_runner = CreateNewThread("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread_task_runner,
                               /*raster=*/thread_task_runner,
                               /*ui=*/thread_task_runner,
                               /*io=*/thread_task_runner);
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory new] autorelease];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);
  UIView* mockFlutterView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)] autorelease];
  flutterPlatformViewsController->SetFlutterView(mockFlutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::MakeScale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  // Push a translate matrix
  SkMatrix translateMatrix = SkMatrix::MakeTrans(100, 100);
  stack.PushTransform(translateMatrix);
  SkMatrix finalMatrix;
  finalMatrix.setConcat(screenScaleMatrix, translateMatrix);

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);

  flutterPlatformViewsController->GetPlatformViewRect(2);

  XCTAssertNotNil(gMockPlatformView);
}

- (void)testCanCreatePlatformViewWithoutFlutterView {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread_task_runner = CreateNewThread("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread_task_runner,
                               /*raster=*/thread_task_runner,
                               /*ui=*/thread_task_runner,
                               /*io=*/thread_task_runner);
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory new] autorelease];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);
}

- (void)testChildClippingViewHitTests {
  ChildClippingView* childClippingView =
      [[[ChildClippingView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)] autorelease];
  UIView* childView = [[[UIView alloc] initWithFrame:CGRectMake(100, 100, 100, 100)] autorelease];
  [childClippingView addSubview:childView];

  XCTAssertFalse([childClippingView pointInside:CGPointMake(50, 50) withEvent:nil]);
  XCTAssertFalse([childClippingView pointInside:CGPointMake(99, 100) withEvent:nil]);
  XCTAssertFalse([childClippingView pointInside:CGPointMake(100, 99) withEvent:nil]);
  XCTAssertFalse([childClippingView pointInside:CGPointMake(201, 200) withEvent:nil]);
  XCTAssertFalse([childClippingView pointInside:CGPointMake(200, 201) withEvent:nil]);
  XCTAssertFalse([childClippingView pointInside:CGPointMake(99, 200) withEvent:nil]);
  XCTAssertFalse([childClippingView pointInside:CGPointMake(200, 299) withEvent:nil]);

  XCTAssertTrue([childClippingView pointInside:CGPointMake(150, 150) withEvent:nil]);
  XCTAssertTrue([childClippingView pointInside:CGPointMake(100, 100) withEvent:nil]);
  XCTAssertTrue([childClippingView pointInside:CGPointMake(199, 100) withEvent:nil]);
  XCTAssertTrue([childClippingView pointInside:CGPointMake(100, 199) withEvent:nil]);
  XCTAssertTrue([childClippingView pointInside:CGPointMake(199, 199) withEvent:nil]);
}

- (void)testCompositePlatformView {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread_task_runner = CreateNewThread("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread_task_runner,
                               /*raster=*/thread_task_runner,
                               /*ui=*/thread_task_runner,
                               /*io=*/thread_task_runner);
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory new] autorelease];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* mockFlutterView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)] autorelease];
  flutterPlatformViewsController->SetFlutterView(mockFlutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::MakeScale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  // Push a translate matrix
  SkMatrix translateMatrix = SkMatrix::MakeTrans(100, 100);
  stack.PushTransform(translateMatrix);
  SkMatrix finalMatrix;
  finalMatrix.setConcat(screenScaleMatrix, translateMatrix);

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  CGRect platformViewRectInFlutterView = [gMockPlatformView convertRect:gMockPlatformView.bounds
                                                                 toView:mockFlutterView];
  XCTAssertTrue(CGRectEqualToRect(platformViewRectInFlutterView, CGRectMake(100, 100, 300, 300)));
}

- (void)testChildClippingViewShouldBeTheBoundingRectOfPlatformView {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread_task_runner = CreateNewThread("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread_task_runner,
                               /*raster=*/thread_task_runner,
                               /*ui=*/thread_task_runner,
                               /*io=*/thread_task_runner);
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory new] autorelease];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* mockFlutterView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)] autorelease];
  flutterPlatformViewsController->SetFlutterView(mockFlutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::MakeScale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  // Push a rotate matrix
  SkMatrix rotateMatrix;
  rotateMatrix.setRotate(10);
  stack.PushTransform(rotateMatrix);
  SkMatrix finalMatrix;
  finalMatrix.setConcat(screenScaleMatrix, rotateMatrix);

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  CGRect platformViewRectInFlutterView = [gMockPlatformView convertRect:gMockPlatformView.bounds
                                                                 toView:mockFlutterView];
  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:ChildClippingView.class]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  // The childclippingview's frame is set based on flow, but the platform view's frame is set based
  // on quartz. Although they should be the same, but we should tolerate small floating point
  // errors.
  XCTAssertLessThan(fabs(platformViewRectInFlutterView.origin.x - childClippingView.frame.origin.x),
                    kFloatCompareEpsilon);
  XCTAssertLessThan(fabs(platformViewRectInFlutterView.origin.y - childClippingView.frame.origin.y),
                    kFloatCompareEpsilon);
  XCTAssertLessThan(
      fabs(platformViewRectInFlutterView.size.width - childClippingView.frame.size.width),
      kFloatCompareEpsilon);
  XCTAssertLessThan(
      fabs(platformViewRectInFlutterView.size.height - childClippingView.frame.size.height),
      kFloatCompareEpsilon);
}

- (void)testClipRect {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread_task_runner = CreateNewThread("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread_task_runner,
                               /*raster=*/thread_task_runner,
                               /*ui=*/thread_task_runner,
                               /*io=*/thread_task_runner);
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory new] autorelease];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* mockFlutterView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)] autorelease];
  flutterPlatformViewsController->SetFlutterView(mockFlutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::MakeScale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  // Push a clip rect
  SkRect rect = SkRect::MakeXYWH(2, 2, 3, 3);
  stack.PushClipRect(rect);

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(10, 10), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  gMockPlatformView.backgroundColor = UIColor.redColor;
  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:ChildClippingView.class]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [mockFlutterView addSubview:childClippingView];

  [mockFlutterView setNeedsLayout];
  [mockFlutterView layoutIfNeeded];

  for (int i = 0; i < 10; i++) {
    for (int j = 0; j < 10; j++) {
      CGPoint point = CGPointMake(i, j);
      int alpha = [self alphaOfPoint:CGPointMake(i, j) onView:mockFlutterView];
      // Edges of the clipping might have a semi transparent pixel, we only check the pixels that
      // are fully inside the clipped area.
      CGRect insideClipping = CGRectMake(3, 3, 1, 1);
      if (CGRectContainsPoint(insideClipping, point)) {
        XCTAssertEqual(alpha, 255);
      } else {
        XCTAssertLessThan(alpha, 255);
      }
    }
  }
}

- (void)testClipRRect {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread_task_runner = CreateNewThread("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread_task_runner,
                               /*raster=*/thread_task_runner,
                               /*ui=*/thread_task_runner,
                               /*io=*/thread_task_runner);
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory new] autorelease];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* mockFlutterView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)] autorelease];
  flutterPlatformViewsController->SetFlutterView(mockFlutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::MakeScale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  // Push a clip rrect
  SkRRect rrect = SkRRect::MakeRectXY(SkRect::MakeXYWH(2, 2, 6, 6), 1, 1);
  stack.PushClipRRect(rrect);

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(10, 10), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  gMockPlatformView.backgroundColor = UIColor.redColor;
  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:ChildClippingView.class]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [mockFlutterView addSubview:childClippingView];

  [mockFlutterView setNeedsLayout];
  [mockFlutterView layoutIfNeeded];

  for (int i = 0; i < 10; i++) {
    for (int j = 0; j < 10; j++) {
      CGPoint point = CGPointMake(i, j);
      int alpha = [self alphaOfPoint:CGPointMake(i, j) onView:mockFlutterView];
      // Edges of the clipping might have a semi transparent pixel, we only check the pixels that
      // are fully inside the clipped area.
      CGRect insideClipping = CGRectMake(3, 3, 4, 4);
      if (CGRectContainsPoint(insideClipping, point)) {
        XCTAssertEqual(alpha, 255);
      } else {
        XCTAssertLessThan(alpha, 255);
      }
    }
  }
}

- (void)testClipPath {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread_task_runner = CreateNewThread("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread_task_runner,
                               /*raster=*/thread_task_runner,
                               /*ui=*/thread_task_runner,
                               /*io=*/thread_task_runner);
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory new] autorelease];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  UIView* mockFlutterView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)] autorelease];
  flutterPlatformViewsController->SetFlutterView(mockFlutterView);
  // Create embedded view params
  flutter::MutatorsStack stack;
  // Layer tree always pushes a screen scale factor to the stack
  SkMatrix screenScaleMatrix =
      SkMatrix::MakeScale([UIScreen mainScreen].scale, [UIScreen mainScreen].scale);
  stack.PushTransform(screenScaleMatrix);
  // Push a clip path
  SkPath path;
  path.addRoundRect(SkRect::MakeXYWH(2, 2, 6, 6), 1, 1);
  stack.PushClipPath(path);

  auto embeddedViewParams =
      std::make_unique<flutter::EmbeddedViewParams>(screenScaleMatrix, SkSize::Make(10, 10), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  gMockPlatformView.backgroundColor = UIColor.redColor;
  XCTAssertTrue([gMockPlatformView.superview.superview isKindOfClass:ChildClippingView.class]);
  ChildClippingView* childClippingView = (ChildClippingView*)gMockPlatformView.superview.superview;
  [mockFlutterView addSubview:childClippingView];

  [mockFlutterView setNeedsLayout];
  [mockFlutterView layoutIfNeeded];

  for (int i = 0; i < 10; i++) {
    for (int j = 0; j < 10; j++) {
      CGPoint point = CGPointMake(i, j);
      int alpha = [self alphaOfPoint:CGPointMake(i, j) onView:mockFlutterView];
      // Edges of the clipping might have a semi transparent pixel, we only check the pixels that
      // are fully inside the clipped area.
      CGRect insideClipping = CGRectMake(3, 3, 4, 4);
      if (CGRectContainsPoint(insideClipping, point)) {
        XCTAssertEqual(alpha, 255);
      } else {
        XCTAssertLessThan(alpha, 255);
      }
    }
  }
}

- (void)testSetFlutterViewControllerAfterCreateCanStillDispatchTouchEvents {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread_task_runner = CreateNewThread("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread_task_runner,
                               /*raster=*/thread_task_runner,
                               /*ui=*/thread_task_runner,
                               /*io=*/thread_task_runner);
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory new] autorelease];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  // Find touch inteceptor view
  UIView* touchInteceptorView = gMockPlatformView;
  while (touchInteceptorView != nil &&
         ![touchInteceptorView isKindOfClass:[FlutterTouchInterceptingView class]]) {
    touchInteceptorView = touchInteceptorView.superview;
  }
  XCTAssertNotNil(touchInteceptorView);

  // Find ForwardGestureRecognizer
  UIGestureRecognizer* forwardGectureRecognizer = nil;
  for (UIGestureRecognizer* gestureRecognizer in touchInteceptorView.gestureRecognizers) {
    if ([gestureRecognizer isKindOfClass:NSClassFromString(@"ForwardingGestureRecognizer")]) {
      forwardGectureRecognizer = gestureRecognizer;
      break;
    }
  }

  // Before setting flutter view controller, events are not dispatched.
  NSSet* touches1 = OCMClassMock([NSSet class]);
  UIEvent* event1 = OCMClassMock([UIEvent class]);
  UIViewController* mockFlutterViewContoller = OCMClassMock([UIViewController class]);
  [forwardGectureRecognizer touchesBegan:touches1 withEvent:event1];
  OCMReject([mockFlutterViewContoller touchesBegan:touches1 withEvent:event1]);

  // Set flutter view controller allows events to be dispatched.
  NSSet* touches2 = OCMClassMock([NSSet class]);
  UIEvent* event2 = OCMClassMock([UIEvent class]);
  flutterPlatformViewsController->SetFlutterViewController(mockFlutterViewContoller);
  [forwardGectureRecognizer touchesBegan:touches2 withEvent:event2];
  OCMVerify([mockFlutterViewContoller touchesBegan:touches2 withEvent:event2]);
}

- (void)testFlutterPlatformViewControllerSubmitFrameWithoutFlutterViewNotCrashing {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread_task_runner = CreateNewThread("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread_task_runner,
                               /*raster=*/thread_task_runner,
                               /*ui=*/thread_task_runner,
                               /*io=*/thread_task_runner);
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/flutter::IOSRenderingAPI::kSoftware,
      /*task_runners=*/runners);

  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory new] autorelease];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  // Create embedded view params
  flutter::MutatorsStack stack;
  SkMatrix finalMatrix;

  auto embeddedViewParams_1 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams_1));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  auto mock_surface = std::make_unique<flutter::SurfaceFrame>(
      nullptr, true,
      [](const flutter::SurfaceFrame& surface_frame, SkCanvas* canvas) { return false; });
  XCTAssertFalse(
      flutterPlatformViewsController->SubmitFrame(nullptr, nullptr, std::move(mock_surface)));

  auto embeddedViewParams_2 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams_2));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  auto mock_surface_submit_false = std::make_unique<flutter::SurfaceFrame>(
      nullptr, true,
      [](const flutter::SurfaceFrame& surface_frame, SkCanvas* canvas) { return true; });
  XCTAssertTrue(flutterPlatformViewsController->SubmitFrame(nullptr, nullptr,
                                                            std::move(mock_surface_submit_false)));
}

- (void)testFlutterPlatformViewControllerBeginFrameShouldResetCompisitionOrder {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread_task_runner = CreateNewThread("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread_task_runner,
                               /*raster=*/thread_task_runner,
                               /*ui=*/thread_task_runner,
                               /*io=*/thread_task_runner);
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/flutter::IOSRenderingAPI::kSoftware,
      /*task_runners=*/runners);

  UIView* mockFlutterView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)] autorelease];
  flutterPlatformViewsController->SetFlutterView(mockFlutterView);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory new] autorelease];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };

  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @0, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  // First frame, |GetCurrentCanvases| is not empty after composite.
  flutterPlatformViewsController->BeginFrame(SkISize::Make(300, 300));
  flutter::MutatorsStack stack;
  SkMatrix finalMatrix;
  auto embeddedViewParams1 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(0, std::move(embeddedViewParams1));
  flutterPlatformViewsController->CompositeEmbeddedView(0);
  XCTAssertEqual(flutterPlatformViewsController->GetCurrentCanvases().size(), 1UL);

  // Second frame, |GetCurrentCanvases| should be empty at the start
  flutterPlatformViewsController->BeginFrame(SkISize::Make(300, 300));
  XCTAssertTrue(flutterPlatformViewsController->GetCurrentCanvases().empty());

  auto embeddedViewParams2 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(0, std::move(embeddedViewParams2));
  flutterPlatformViewsController->CompositeEmbeddedView(0);
  XCTAssertEqual(flutterPlatformViewsController->GetCurrentCanvases().size(), 1UL);
}

- (void)testFlutterPlatformViewControllerSubmitFrameWithoutFlutterViewNotCrashing {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread_task_runner = CreateNewThread("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread_task_runner,
                               /*raster=*/thread_task_runner,
                               /*ui=*/thread_task_runner,
                               /*io=*/thread_task_runner);
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory new] autorelease];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  XCTAssertNotNil(gMockPlatformView);

  // Create embedded view params
  flutter::MutatorsStack stack;
  SkMatrix finalMatrix;

  auto embeddedViewParams_1 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);

  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams_1));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  auto mock_surface = std::make_unique<flutter::SurfaceFrame>(
      nullptr, true,
      [](const flutter::SurfaceFrame& surface_frame, SkCanvas* canvas) { return false; });
  auto is_gpu_disabled = std::make_shared<fml::SyncSwitch>();
  is_gpu_disabled->SetSwitch(false);
  XCTAssertFalse(flutterPlatformViewsController->SubmitFrame(
      nullptr, nullptr, std::move(mock_surface), is_gpu_disabled));

  auto embeddedViewParams_2 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams_2));
  flutterPlatformViewsController->CompositeEmbeddedView(2);
  auto mock_surface_submit_false = std::make_unique<flutter::SurfaceFrame>(
      nullptr, true,
      [](const flutter::SurfaceFrame& surface_frame, SkCanvas* canvas) { return true; });
  auto gpu_is_disabled = std::make_shared<fml::SyncSwitch>();
  gpu_is_disabled->SetSwitch(false);
  XCTAssertTrue(flutterPlatformViewsController->SubmitFrame(
      nullptr, nullptr, std::move(mock_surface_submit_false), gpu_is_disabled));
}

- (void)
    testFlutterPlatformViewControllerResetDeallocsPlatformViewWhenRootViewsNotBindedToFlutterView {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread_task_runner = CreateNewThread("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread_task_runner,
                               /*raster=*/thread_task_runner,
                               /*ui=*/thread_task_runner,
                               /*io=*/thread_task_runner);
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners);

  UIView* mockFlutterView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)] autorelease];
  flutterPlatformViewsController->SetFlutterView(mockFlutterView);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory new] autorelease];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };
  // autorelease pool to trigger an autorelease for all the root_views_ and touch_interceptors_.
  @autoreleasepool {
    flutterPlatformViewsController->OnMethodCall(
        [FlutterMethodCall
            methodCallWithMethodName:@"create"
                           arguments:@{@"id" : @2, @"viewType" : @"MockFlutterPlatformView"}],
        result);

    flutter::MutatorsStack stack;
    SkMatrix finalMatrix;
    auto embeddedViewParams =
        std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
    flutterPlatformViewsController->PrerollCompositeEmbeddedView(2, std::move(embeddedViewParams));
    flutterPlatformViewsController->CompositeEmbeddedView(2);
    // Not calling |flutterPlatformViewsController::SubmitFrame| so that the platform views are not
    // added to flutter_view_.

    XCTAssertNotNil(gMockPlatformView);
    flutterPlatformViewsController->Reset();
  }
  XCTAssertNil(gMockPlatformView);
}

- (void)testFlutterPlatformViewControllerBeginFrameShouldResetCompisitionOrder {
  flutter::FlutterPlatformViewsTestMockPlatformViewDelegate mock_delegate;
  auto thread_task_runner = CreateNewThread("FlutterPlatformViewsTest");
  flutter::TaskRunners runners(/*label=*/self.name.UTF8String,
                               /*platform=*/thread_task_runner,
                               /*raster=*/thread_task_runner,
                               /*ui=*/thread_task_runner,
                               /*io=*/thread_task_runner);
  auto flutterPlatformViewsController = std::make_shared<flutter::FlutterPlatformViewsController>();
  auto platform_view = std::make_unique<flutter::PlatformViewIOS>(
      /*delegate=*/mock_delegate,
      /*rendering_api=*/flutter::IOSRenderingAPI::kSoftware,
      /*platform_views_controller=*/flutterPlatformViewsController,
      /*task_runners=*/runners);

  UIView* mockFlutterView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 500, 500)] autorelease];
  flutterPlatformViewsController->SetFlutterView(mockFlutterView);

  FlutterPlatformViewsTestMockFlutterPlatformFactory* factory =
      [[FlutterPlatformViewsTestMockFlutterPlatformFactory new] autorelease];
  flutterPlatformViewsController->RegisterViewFactory(
      factory, @"MockFlutterPlatformView",
      FlutterPlatformViewGestureRecognizersBlockingPolicyEager);
  FlutterResult result = ^(id result) {
  };

  flutterPlatformViewsController->OnMethodCall(
      [FlutterMethodCall
          methodCallWithMethodName:@"create"
                         arguments:@{@"id" : @0, @"viewType" : @"MockFlutterPlatformView"}],
      result);

  // First frame, |GetCurrentCanvases| is not empty after composite.
  flutterPlatformViewsController->BeginFrame(SkISize::Make(300, 300));
  flutter::MutatorsStack stack;
  SkMatrix finalMatrix;
  auto embeddedViewParams1 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(0, std::move(embeddedViewParams1));
  flutterPlatformViewsController->CompositeEmbeddedView(0);
  XCTAssertEqual(flutterPlatformViewsController->GetCurrentCanvases().size(), 1UL);

  // Second frame, |GetCurrentCanvases| should be empty at the start
  flutterPlatformViewsController->BeginFrame(SkISize::Make(300, 300));
  XCTAssertTrue(flutterPlatformViewsController->GetCurrentCanvases().empty());

  auto embeddedViewParams2 =
      std::make_unique<flutter::EmbeddedViewParams>(finalMatrix, SkSize::Make(300, 300), stack);
  flutterPlatformViewsController->PrerollCompositeEmbeddedView(0, std::move(embeddedViewParams2));
  flutterPlatformViewsController->CompositeEmbeddedView(0);
  XCTAssertEqual(flutterPlatformViewsController->GetCurrentCanvases().size(), 1UL);
}

- (int)alphaOfPoint:(CGPoint)point onView:(UIView*)view {
  unsigned char pixel[4] = {0};

  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

  // Draw the pixel on `point` in the context.
  CGContextRef context = CGBitmapContextCreate(
      pixel, 1, 1, 8, 4, colorSpace, kCGBitmapAlphaInfoMask & kCGImageAlphaPremultipliedLast);
  CGContextTranslateCTM(context, -point.x, -point.y);
  [view.layer renderInContext:context];

  CGContextRelease(context);
  CGColorSpaceRelease(colorSpace);
  // Get the alpha from the pixel that we just rendered.
  return pixel[3];
}

@end
