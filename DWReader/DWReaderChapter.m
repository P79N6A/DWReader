//
//  DWReaderChapter.m
//  DWReader
//
//  Created by Wicky on 2019/2/12.
//  Copyright © 2019 Wicky. All rights reserved.
//

#import "DWReaderChapter.h"
#import <CoreText/CoreText.h>

///缩进长度
#define kIndentLength (2)
///缩进符号
#define kIndentString @"\t\t"
///段落分隔符长度
#define kSeperateParagraphLength (4)
///段落分隔符符号
#define kSeperateParagraphString @"\n\n\t\t"
///段落结尾至空白符中间的长度
#define kFooterLineBreakLength (1)
///空白符符号
#define kBlankSymbol 0xFFFC
///空白符符号长度
#define kBlankSymbolLength (1)
///段落间的偏移量
#define kParagraphOffset (kSeperateParagraphLength + kBlankSymbolLength - kIndentLength)
///段落起始位置距离段落正文起始位置偏移量
#define kContentOffset (kParagraphOffset - kFooterLineBreakLength)


///安全释放
#define CFSAFERELEASE(a)\
do {\
if(a) {\
CFRelease(a);\
a = NULL;\
}\
} while(0);

@interface DWReaderChapter ()

///分段后的正文内容
@property (nonatomic ,strong) NSMutableString * parsedString;

///绘制文本
@property (nonatomic ,strong) NSMutableAttributedString * drawString;

@end

@implementation DWReaderChapter

#pragma mark --- interface method ---
+(instancetype)chapterWithOriginString:(NSString *)oriStr title:(NSString *)title renderSize:(CGSize)renderSize {
    return [[self alloc] initWithOriginString:oriStr title:title renderSize:renderSize];
}

-(instancetype)initWithOriginString:(NSString *)oriStr title:(NSString *)title renderSize:(CGSize)renderSize {
    if (self = [super init]) {
        _originString = oriStr;
        _title = title;
        _renderSize = renderSize;
        _content = nil;
        _paragraphs = nil;
        _parsedString = nil;
        _fontSize = MAXFLOAT;
        _titleSpacing = MAXFLOAT;
        _lineSpacing = MAXFLOAT;
        _paragraphSpacing = MAXFLOAT;
    }
    return self;
}

-(void)parseChapter {
    NSMutableString * content = [NSMutableString stringWithString:_originString];
    
    ///去除文本原有制表符，后续将以制表符做段首缩进
    [[[NSRegularExpression alloc] initWithPattern:@"\\t+" options:0 error:nil] replaceMatchesInString:content options:0 range:NSMakeRange(0, content.length) withTemplate:@""];
    
    
    ///替换换行符为分段符（\n\n\t\t，这么做是因为两个换行符间可插入空白字符调整段落间距，两个制表符可作为段首缩进。后期可调整段首缩进的字符串及长度，修改宏即可）
    [[[NSRegularExpression alloc] initWithPattern:@"\\n+" options:0 error:nil] replaceMatchesInString:content options:0 range:NSMakeRange(0, content.length) withTemplate:kSeperateParagraphString];
    
    ///去除段首段尾的分段符
    if ([content hasPrefix:kSeperateParagraphString]) {
        [content replaceCharactersInRange:NSMakeRange(0, kSeperateParagraphLength) withString:@""];
    }
    if ([content hasSuffix:kSeperateParagraphString]) {
        [content replaceCharactersInRange:NSMakeRange(content.length - kSeperateParagraphLength, kSeperateParagraphLength) withString:@""];
    }
    
    ///获取段落以后处理段首缩进及段落间距，由于之前去除了段首的分段符，所以现在首先应该给段首添加缩进
    [content insertString:kIndentString atIndex:0];
    
    ///匹配段落
    NSArray <NSTextCheckingResult *>* results = [[[NSRegularExpression alloc] initWithPattern:kSeperateParagraphString options:0 error:nil] matchesInString:content options:0 range:NSMakeRange(0, content.length)];
    
    ///然后计算段落信息
    NSUInteger resultsCnt = results.count;
    NSMutableArray <DWReaderParagraph *>* paraTmp = [NSMutableArray arrayWithCapacity:resultsCnt + 1];
    __block NSUInteger lastLoc = 0;
    [results enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        lastLoc = [self seperateParagraphWithString:content paras:paraTmp lastLoc:lastLoc nextLoc:obj.range.location];
    }];
    
    ///补充最后一段
    [self seperateParagraphWithString:content paras:paraTmp lastLoc:lastLoc nextLoc:content.length];
    
    _paragraphs = [paraTmp copy];
    self.parsedString = content;
    
    NSLog(@"%@",paraTmp);
    NSLog(@"\n%@",self.parsedString);
    
    ///至此字符串已经完成分段，在正文内容不变的情况下，字符串可以保留，改变字号后重新计算分页即可
}

-(void)seperatePageWithFontSize:(CGFloat)fontSize titleSpacing:(CGFloat)titleSpacing lineSpacing:(CGFloat)lineSpacing paragraphSpacing:(CGFloat)paragraphSpacing {
    ///当任意一个影响分页的数据改变时才重新计算分页
    if (self.fontSize != fontSize || self.titleSpacing != titleSpacing || self.lineSpacing != lineSpacing || self.paragraphSpacing != paragraphSpacing) {
        
        ///赋值基础属性并清空之前的分页数据
        _fontSize = fontSize;
        _titleSpacing = titleSpacing;
        _lineSpacing = lineSpacing;
        _paragraphSpacing = paragraphSpacing;
        _pages = nil;
        
        ///组装富文本
        [self configAttributeString];
        
        ///富文本组装完成后可以开始分页
        [self seperatePage];
    }
}

-(void)configTextColor:(UIColor *)textColor {
    if (![self.textColor isEqual:textColor]) {
        _textColor = textColor;
    }
}

#pragma mark --- tool method ---
-(NSUInteger)seperateParagraphWithString:(NSMutableString *)str paras:(NSMutableArray <DWReaderParagraph *>*)paras lastLoc:(NSUInteger)lastLoc nextLoc:(NSUInteger)nextLoc {
    
    ///计算段落信息，其中LastLoc表示计算本段落的起始位置，nextLoc表示结束位置。起始位置除手段从默认值0开始计算以外，其他均为上一段落结束位置后加一个结尾换行符的长度的位置。结束位置及每次匹配到的分段符的Location。（语言表述能力有限，实在想不明白建议画个图）
    DWReaderParagraph * para = [DWReaderParagraph new];
    para.range = NSMakeRange(lastLoc,nextLoc - lastLoc);
    
    ///如果这是第一段，改变标志位，标志首段，如果不是，将数组中最后一段的下一段置位本段
    if (paras.count != 0) {
        para.prevParagraph = paras.lastObject;
        paras.lastObject.nextParagraph = para;
    }
    
    para.index = paras.count;
    ///第0段和第1段不用修，因为第0段不插入空白符，第1段为第一个插入的空白符，故两段不用修range
    if (para.index < 2) {
        para.fixRange = para.range;
    } else {
        para.fixRange = NSMakeRange(para.range.location + (para.index - 1) * kBlankSymbolLength, para.range.length);
    }
    
    [paras addObject:para];
    
    ///之所以要加一个结尾换行符长度是因为在结尾换行符后我们后续会添加空白字符来调整段落间距，事实上我们分段就是为了找这个位置及段首缩进。所以找到这个位置很重要
    return para.range.location + para.range.length + kFooterLineBreakLength;
}

-(void)configAttributeString {
    ///获取将要绘制的富文本，主要设置字号、行间距属性、添加空白字符
    self.drawString = nil;
    NSMutableAttributedString * draw = [[NSMutableAttributedString alloc] initWithString:self.parsedString];
    
    ///插入空白字符，调整段落间距
    DWReaderParagraph * para = self.paragraphs.firstObject.nextParagraph;
    while (para) {
        [self insertPlaceholderForDrawString:draw withParagraph:para];
        para = para.nextParagraph;
    }
    
    NSRange range = NSMakeRange(0, draw.length);
    ///设置字符串属性（字号、行间距）
    [draw addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:self.fontSize] range:range];
    NSMutableParagraphStyle * paraStyle = [[NSMutableParagraphStyle alloc] init];
    paraStyle.lineSpacing = self.lineSpacing;
    [draw addAttribute:NSParagraphStyleAttributeName value:paraStyle range:range];
    
    self.drawString = draw;
}

-(void)seperatePage {
    ///第一页存在标题，所以首页处理不同。首页应先绘制标题，绘制标题过后计算首页正文绘制区域，来进行首页的分页。其余页的分页均以渲染区域进行分页，每个新页中要考虑新页的起始位置是否是分段的换行符或空白字符，如果是，要排除掉此区域在计算分页
    UIFont * titleFont = [UIFont systemFontOfSize:self.fontSize * 1.5];
    UILabel * tmpLb = [[UILabel alloc] initWithFrame:(CGRect){CGPointZero,self.renderSize}];
    tmpLb.font = titleFont;
    tmpLb.numberOfLines = 0;
    tmpLb.text = self.title;
    [tmpLb sizeToFit];
    
    ///计算首页渲染区域
    CGFloat title_h = tmpLb.bounds.size.height;
    CGFloat offset_y = title_h + self.titleSpacing;
    CGSize firstParagraphRenderSize = CGSizeMake(self.renderSize.width, self.renderSize.height - offset_y);
    
    NSMutableArray * tmpPages = [NSMutableArray arrayWithCapacity:0];
    
    ///说明标题过大，不足以再绘制正文，此时正文应该另起一页
    if (firstParagraphRenderSize.height < 0) {
        DWReaderPage * titlePage = [[DWReaderPage alloc] init];
        titlePage.needRenderTitle = YES;
        [tmpPages addObject:titlePage];
    }
    
    NSUInteger currentLoc = 0;
    ///当前手机以xs max做最大屏幕，14号字做最小字号，18像素为最小行间距，最大展示字数为564个字，取整估算为600字，为避免因数字较多在成的字形大小差距的影响，乘以1.2倍的安全余量，故当前安全阈值为720字
    NSUInteger length = self.drawString.length - currentLoc;
    DWReaderParagraph * currentPara = self.paragraphs.firstObject;
    while (length > 0) {
        length = MIN(length, 720);
        
        ///截取一段字符串
        NSAttributedString * sub = [self.drawString attributedSubstringFromRange:NSMakeRange(currentLoc, length)];
        ///选定渲染区域
        CGSize size = tmpPages.count == 0 ? firstParagraphRenderSize : self.renderSize;
        NSRange range = [self calculateVisibleRangeWithString:sub renderSize:size location:currentLoc];
        if (range.length == 0) {
            ///计算出错
            NSAssert(NO, @"DWReader can't calculate visible range,currentLoc = %lu,length = %lu,size = %@,sub = %@",currentLoc,length,NSStringFromCGSize(size),sub.string);
            break;
        }
        
        ///配置分页信息
        DWReaderPage * page = [[DWReaderPage alloc] init];
        page.range = range;
        page.page = tmpPages.count;
        page.pageContent = [self.drawString attributedSubstringFromRange:range];
        if (page.page == 0) {
            page.offsetY = offset_y;
            page.needRenderTitle = YES;
        }
        [tmpPages addObject:page];
        
        ///更改currentLoc，此处应根据分段决定下一个Loc。首先应找到现在属于哪个段落
        currentLoc = NSMaxRange(range);
        if (currentLoc > currentPara.fixRange.location && currentLoc < NSMaxRange(currentPara.fixRange)) {
            ///在当前段落内，不涉及到分段符，currentLoc及currentPara均不需要修正
        } else if (currentLoc > NSMaxRange(currentPara.fixRange) && currentLoc < (NSMaxRange(currentPara.fixRange) + kParagraphOffset)) {
            ///不在当前段落，但还没有到下一段落的实际正文处，即当前处于两个段落间的分段处，此时currentLoc应该修正为下一段的实际真跟处，currentPara应该修正为下一段。另外如果存在下一段则修正，不存在的话，分页完毕。
            if (currentPara.nextParagraph) {
                ///修正段落为下一段
                currentPara = currentPara.nextParagraph;
                ///修正位置为下一段正文位置
                currentLoc = currentPara.fixRange.location + kContentOffset;
            } else {
                break;
            }
        } else {
            ///当位置在更往后的位置是，可能在下一段中，或者下下段中，需要找到对应段，并根据上述规则修正
            while (currentPara.nextParagraph) {
                ///如果在下一段的正文至下下段的正文之间，则认为找到所在段落，否则继续查找下下段
                currentPara = currentPara.nextParagraph;
                if (currentLoc > currentPara.fixRange.location + kContentOffset && currentLoc < NSMaxRange(currentPara.fixRange) + kParagraphOffset) {
                    break;
                }
            }
            
            ///至此两种情况：1.找到了所在段落，则可以开始修正currentLoc。2.未找到所在段落，但下一段为空，则分页结束
            if (!currentPara) {
                break;
            } else {
                ///如果在当前段落与下一段落间的分割区间则按照之前逻辑进行修正，否则无需修正，因为范围已经限定为在当前段落正文之间了。
                if (currentLoc > NSMaxRange(currentPara.fixRange) && currentLoc < (NSMaxRange(currentPara.fixRange) + kParagraphOffset)) {
                    if (currentPara.nextParagraph) {
                        currentPara = currentPara.nextParagraph;
                        currentLoc = currentPara.fixRange.location + kContentOffset;
                    } else {
                        break;
                    }
                }
            }
        }
        length = self.drawString.length - currentLoc;
    }
    
    ///至此分页完毕
    NSLog(@"%@",tmpPages);
}

-(void)insertPlaceholderForDrawString:(NSMutableAttributedString *)draw withParagraph:(DWReaderParagraph *)para {
    if (para.fixRange.location > draw.length) {
        return;
    }
    
    NSDictionary * dic = @{@"size":[NSValue valueWithCGSize:CGSizeMake(self.renderSize.width, self.paragraphSpacing - 2 * self.lineSpacing)]};
    CTRunDelegateCallbacks callBacks;
    memset(&callBacks, 0, sizeof(CTRunDelegateCallbacks));
    callBacks.version = kCTRunDelegateVersion1;
    callBacks.getAscent = ascentCallBacks;
    callBacks.getDescent = descentCallBacks;
    callBacks.getWidth = widthCallBacks;
    CTRunDelegateRef delegate = CTRunDelegateCreate(&callBacks, (__bridge_retained void *)dic);
    unichar placeHolder = kBlankSymbol;
    NSString * placeHolderStr = [NSString stringWithCharacters:&placeHolder length:1];
    NSMutableAttributedString * placeHolderAttrStr = [[NSMutableAttributedString alloc] initWithString:placeHolderStr];
    CFAttributedStringSetAttribute((CFMutableAttributedStringRef)placeHolderAttrStr, CFRangeMake(0, 1), kCTRunDelegateAttributeName, delegate);
    CFSAFERELEASE(delegate);
    [draw insertAttributedString:placeHolderAttrStr atIndex:para.fixRange.location];
}

-(NSRange)calculateVisibleRangeWithString:(NSAttributedString *)string renderSize:(CGSize)size location:(NSUInteger)loc {
    ///利用CoreText计算当前显示区域内可显示的范围
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef) string);
    UIBezierPath * bezierPath = [UIBezierPath bezierPathWithRect:(CGRect){CGPointZero,size}];
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), bezierPath.CGPath, NULL);
    CFRange range = CTFrameGetVisibleStringRange(frame);
    NSRange fixRange = {loc, range.length};
    CFSAFERELEASE(frame);
    CFSAFERELEASE(framesetter);
    return fixRange;
}

#pragma mark --- CoreText callback ---
static CGFloat ascentCallBacks(void * ref) {
    NSDictionary * dic = (__bridge NSDictionary *)ref;
    CGSize size = [dic[@"size"] CGSizeValue];
    return size.height;
}

static CGFloat descentCallBacks(void * ref) {
    return 0;
}

static CGFloat widthCallBacks(void * ref) {
    NSDictionary * dic = (__bridge NSDictionary *)ref;
    CGSize size = [dic[@"size"] CGSizeValue];
    return size.width;
}

#pragma mark --- override ---
-(BOOL)isEqual:(id)object {
    ///比较类
    if (![NSStringFromClass(object) isEqualToString:NSStringFromClass([self class])]) {
        return NO;
    }
    ///比较原始字符串
    if (![((DWReaderChapter *)object).originString isEqualToString:self.originString]) {
        return NO;
    }
    ///比较行间距
    if (((DWReaderChapter *)object).lineSpacing != self.lineSpacing) {
        return NO;
    }
    ///比较段落间距
    if (((DWReaderChapter *)object).paragraphSpacing != self.paragraphSpacing) {
        return NO;
    }
    return YES;
}

@end
