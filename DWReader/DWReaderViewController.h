//
//  DWReaderViewController.h
//  DWReader
//
//  Created by Wicky on 2019/2/16.
//  Copyright © 2019 Wicky. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DWReaderChapterInfo.h"
#import "DWReaderTextConfiguration.h"
#import "DWReaderDisplayConfiguration.h"
#import "DWReaderChapter.h"
#import "DWReaderPageInfo.h"
#import "DWReaderPageViewController.h"

NS_ASSUME_NONNULL_BEGIN

@class DWReaderViewController;

typedef void(^DWReaderRequestDataCompleteCallback)(NSString * title ,NSString * content ,NSString * bookID ,NSString * chapterID ,CGFloat percent,NSInteger chapterIndex ,BOOL nextChapter,_Nullable id userInfo);
typedef void(^DWReaderReprocessorCallback)(DWReaderPageInfo * _Nullable  newFirstPage, DWReaderPageInfo * _Nullable newLastPage,NSUInteger fixTotalPage);
typedef NSString *(^DWReaderQueryChapterIDCallback)(DWReaderViewController * reader ,NSString * bookID ,NSString * currentChapterID ,BOOL nextChapter);
typedef void(^DWReaderRequestBookDataCallback)(DWReaderViewController * reader ,NSString * bookID ,NSString * chapterID ,BOOL nextChapter ,DWReaderRequestDataCompleteCallback requestCompleteCallback);
typedef void(^DWReaderReprocessChapterCallback)(DWReaderViewController * reader ,DWReaderChapter * chapter ,DWReaderReprocessorCallback reprocessor);
typedef void(^DWReaderPageChangeCallback)(DWReaderViewController * reader, DWReaderPageViewController * page);

@protocol DWReaderDataDelegate <NSObject>

@optional

/**
 根据给定信息返回关联的章节ID
 
 @param reader 当前阅读器对象
 @param bookID 当前书籍的bookID
 @param chapterID 当前章节的chapterID
 @param nextChapter 是否询问的是下一章节
 @return 返回指定的章节ID
 */
-(NSString *)reader:(DWReaderViewController *)reader queryChapterIdForBook:(NSString *)bookID currentChapterID:(NSString *)chapterID nextChapter:(BOOL)nextChapter;

/**
 请求对应章节内容

 @param reader 当前阅读器对象
 @param bookID 请求的书籍ID
 @param chapterID 请求的章节ID
 @param callback 请求后回调数据给reader的callback
 */
-(void)reader:(DWReaderViewController *)reader requestBookDataForBook:(NSString *)bookID chapterID:(NSString *)chapterID nextChapter:(BOOL)next requestCompleteCallback:(DWReaderRequestDataCompleteCallback)callback;


/**
 分页完成后完成对页面的二次修改

 @param reader 当前阅读器对象
 @param chapter 当前分章完毕的章节实例
 @param callback 修改当前章节实例首尾页面及总页面数的回调
 */
-(void)reader:(DWReaderViewController *)reader reprocessChapter:(DWReaderChapter *)chapter configChapterCallback:(DWReaderReprocessorCallback)callback;


/**
 将要展示指定页面

 @param reader 当前阅读器对象
 @param page 将要展示的页面控制器
 */
-(void)reader:(DWReaderViewController *)reader willDisplayPage:(DWReaderPageViewController *)page;


/**
 结束展示指定页面

 @param reader 当前阅读器对象
 @param page 结束展示的页面控制器
 */
-(void)reader:(DWReaderViewController *)reader didEndDisplayingPage:(DWReaderPageViewController *)page;

@end

@interface DWReaderViewController : UIPageViewController

///获取书籍数据代理（如果指定代理且代理实现对应方法则优先是否代理方法，否则使用回调方法）
@property (nonatomic ,weak) id<DWReaderDataDelegate> readerDelegate;

///根据给定信息返回指定的章节ID
@property (nonatomic ,copy) DWReaderQueryChapterIDCallback queryChapterIdCallback;

///请求对应章节内容
@property (nonatomic ,copy) DWReaderRequestBookDataCallback requestBookDataCallback;

///分页完成后完成对页面的二次修改
@property (nonatomic ,copy) DWReaderReprocessChapterCallback reprocessChapterCallback;

///将要展示指定页面
@property (nonatomic ,copy) DWReaderPageChangeCallback willDisplayPageCallback;

///结束展示指定页面
@property (nonatomic ,copy) DWReaderPageChangeCallback didEndDisplayingPageCallback;

///需要展示Loading的回调，通常出现在请求章节内容时（非预加载）
@property (nonatomic ,copy) void (^loadingAction) (BOOL show);

///没有更多章节了，last为真表示没有下一章节，否则表示没有上一章节
@property (nonatomic ,copy) void (^noMoreChapter) (BOOL last);


/**
 初始化阅读器

 @param textConf 阅读器文字配置信息
 @param displayConf 阅读器展示配置信息

 @return 阅读器实例
 */
+(instancetype)readerWithTextConfiguration:(DWReaderTextConfiguration *)textConf displayConfiguration:(DWReaderDisplayConfiguration *)displayConf;


/**
 按章节信息配置阅读器

 @param chapterInfo 章节信息
 */
-(void)fetchChapter:(DWReaderChapterInfo *)chapterInfo;

@end

NS_ASSUME_NONNULL_END
