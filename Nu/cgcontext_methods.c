
- (void)addArc:(CGPoint)p radius:(CGFloat)radius startAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle clockwise:(int)clockwise
{
    CGContextAddArc(_context, p.x, p.y, radius, startAngle, endAngle, clockwise);
}
- (void)addArc:(CGPoint)p1 toPoint:(CGPoint)p2 radius:(CGFloat)radius
{
    CGContextAddArcToPoint(_context, p1.x, p1.y, p2.x, p2.y, radius);
}
- (void)addCurve:(CGPoint)cp1 toPoint:(CGPoint)cp2 endPoint:(CGPoint)e
{
    CGContextAddCurveToPoint(_context, cp1.x, cp1.y, cp2.x, cp2.y, e.x, e.y);
}
- (void)addEllipseInRect:(CGRect)rect { CGContextAddEllipseInRect(_context, rect); }
- (void)addLineToPoint:(CGPoint)p { CGContextAddLineToPoint(_context, p.x, p.y); }
- (void)addPath:(CGPath *)path
{
    if (nu_objectIsKindOfClass(path, [CGPath class])) {
        CGContextAddPath(_context, [path pointerValue]);
    }
}
- (void)addQuadCurve:(CGPoint)cp toPoint:(CGPoint)e
{
    CGContextAddQuadCurveToPoint(_context, cp.x, cp.y, e.x, e.y);
}
- (void)addRect:(CGRect)rect { CGContextAddRect(_context, rect); }
- (void)beginPath
{
    CGContextBeginPath(_context);
}
- (void)beginTransparencyLayer:(NSDictionary *)auxiliaryInfo
{
    CGContextBeginTransparencyLayer(_context, (CFDictionaryRef)auxiliaryInfo);
}
- (void)beginTransparencyLayer:(NSDictionary *)auxiliaryInfo withRect:(CGRect)rect
{
    CGContextBeginTransparencyLayerWithRect(_context, rect, (CFDictionaryRef)auxiliaryInfo);
}
- (void)clearRect:(CGRect)rect { CGContextClearRect(_context, rect); }
- (void)clip { CGContextClip(_context); }
- (void)clip:(CGRect)rect toMask:(UIImage *)mask { CGContextClipToMask(_context, rect, [mask CGImage]); }
- (void)clipToRect:(CGRect)rect { CGContextClipToRect(_context, rect); }
- (void)closePath { CGContextClosePath(_context); }
- (void)concatCTM:(CGAffineTransform)transform { CGContextConcatCTM(_context, transform); }
- (void)convertPointToDeviceSpace:(CGPoint)point { CGContextConvertPointToDeviceSpace(_context, point); }
- (void)convertPointToUserSpace:(CGPoint)point { CGContextConvertPointToUserSpace(_context, point); }
- (void)convertRectToDeviceSpace:(CGRect)rect { CGContextConvertRectToDeviceSpace(_context, rect); }
- (void)convertRectToUserSpace:(CGRect)rect { CGContextConvertRectToUserSpace(_context, rect); }
- (void)convertSizeToDeviceSpace:(CGSize)size { CGContextConvertSizeToDeviceSpace(_context, size); }
- (void)convertSizeToUserSpace:(CGSize)size { CGContextConvertSizeToUserSpace(_context, size); }
- (id)copyPath { return [CGPath valueWithPointer:CGContextCopyPath(_context)]; }
- (void)drawImage:(UIImage *)image rect:(CGRect)rect { CGContextDrawImage(_context, rect, [image CGImage]); }
- (void)drawLinearGradient:(CGGradient *)gradient start:(CGPoint)start end:(CGPoint)end options:(CGGradientDrawingOptions)options
{
    CGContextDrawLinearGradient(_context, [gradient CGGradient], start, end, options);
}
- (void)drawPath:(CGPathDrawingMode)mode { CGContextDrawPath(_context, mode); }
- (void)drawRadialGradient:(CGGradient *)gradient startCenter:(CGPoint)startCenter startRadius:(CGFloat)startRadius endCenter:(CGPoint)endCenter endRadius:(CGFloat)endRadius options:(CGGradientDrawingOptions)options
{
    CGContextDrawRadialGradient(_context, [gradient CGGradient], startCenter, startRadius, endCenter, endRadius, options);
}
- (void)drawTiledImage:(UIImage *)image rect:(CGRect)rect { CGContextDrawTiledImage(_context, rect, [image CGImage]); }
- (void)drawPDFPage:(CGPDFPage *)page { CGContextDrawPDFPage(_context, [page CGPDFPage]); }
- (void)endTransparencyLayer { CGContextEndTransparencyLayer(_context); }
- (void)EOClip { CGContextEOClip(_context); }
- (void)EOFillPath { CGContextEOFillPath(_context); }
- (void)fillEllipseInRect:(CGRect)rect { CGContextFillEllipseInRect(_context, rect); }
- (void)fillPath { CGContextFillPath(_context); }
- (void)fillRect:(CGRect)rect { CGContextFillRect(_context, rect); }
- (CGRect)clipBoundingBox { return CGContextGetClipBoundingBox(_context); }
- (CGAffineTransform)ctm { return CGContextGetCTM(_context); }
- (CGInterpolationQuality)interpolationQuality { return CGContextGetInterpolationQuality(_context); }
- (CGRect)pathBoundingBox { return CGContextGetPathBoundingBox(_context); }
- (CGPoint)pathCurrentPoint { return CGContextGetPathCurrentPoint(_context); }
- (CGAffineTransform)textMatrix { return CGContextGetTextMatrix(_context); }
- (CGPoint)textPosition { return CGContextGetTextPosition(_context); }
- (CGAffineTransform)userSpaceToDeviceSpaceTransform { return CGContextGetUserSpaceToDeviceSpaceTransform(_context); }
- (BOOL)isPathEmpty { return CGContextIsPathEmpty(_context); }
- (void)moveToPoint:(CGPoint)p { CGContextMoveToPoint(_context, p.x, p.y); }
- (BOOL)pathContainsPoint:(CGPoint)point mode:(CGPathDrawingMode)mode
{
    return CGContextPathContainsPoint(_context, point, mode);
}
- (void)replacePathWithStrokedPath { CGContextReplacePathWithStrokedPath(_context); }
- (void)restoreGState { CGContextRestoreGState(_context); }
- (void)rotateCTM:(CGFloat)angle { CGContextRotateCTM(_context, angle); }
- (void)saveGState { CGContextSaveGState(_context); }
- (void)scaleCTM:(CGPoint)s { CGContextScaleCTM(_context, s.x, s.y); }
- (void)selectFont:(NSString *)name size:(CGFloat)size encoding:(CGTextEncoding)encoding
{
    CGContextSelectFont(_context, [name UTF8String], size, encoding);
}
- (void)setAllowsAntialiasing:(BOOL)val { CGContextSetAllowsAntialiasing(_context, val); }
- (void)setAllowsFontSmoothing:(BOOL)val { CGContextSetAllowsFontSmoothing(_context, val); }
- (void)setAllowsFontSubpixelPositioning:(BOOL)val { CGContextSetAllowsFontSubpixelPositioning(_context, val); }
- (void)setAllowsFontSubpixelQuantization:(BOOL)val { CGContextSetAllowsFontSubpixelQuantization(_context, val); }
- (void)setAlpha:(CGFloat)alpha { CGContextSetAlpha(_context, alpha); }
- (void)setBlendMode:(int)mode { CGContextSetBlendMode(_context, mode); }
- (void)setCharacterSpacing:(CGFloat)spacing { CGContextSetCharacterSpacing(_context, spacing); }
- (void)setCMYKFillColor:(CGRect)color alpha:(CGFloat)alpha { CGContextSetCMYKFillColor(_context, color.origin.x, color.origin.y, color.size.width, color.size.height, alpha); }
- (void)setCMYKStrokeColor:(CGRect)color alpha:(CGFloat)alpha { CGContextSetCMYKStrokeColor(_context, color.origin.x, color.origin.y, color.size.width, color.size.height, alpha); }
- (void)setFillColorSpace:(CGColorSpace *)colorspace
{
    if (nu_objectIsKindOfClass(colorspace, [CGColorSpace class])) {
        CGContextSetFillColorSpace(_context, [colorspace pointerValue]);
    }
}
- (void)setFillColorWithColor:(UIColor *)color { CGContextSetFillColorWithColor(_context, [color CGColor]); }
- (void)setFillPattern:(CGPattern *)pattern color:(CGRect)color
{
    CGContextSetFillColorSpace(_context, [pattern colorspace]);
    CGContextSetFillPattern(_context, [pattern pattern], &color);
}
- (void)setFlatness:(CGFloat)flatness { CGContextSetFlatness(_context, flatness); }
- (void)setFont:(CGFont *)font
{
    CGContextSetFont(_context, [font CGFont]);
}
- (void)setFontSize:(CGFloat)size { CGContextSetFontSize(_context, size); }
- (void)setGrayFillColor:(CGFloat)gray alpha:(CGFloat)alpha { CGContextSetGrayFillColor(_context, gray, alpha); }
- (void)setGrayStrokeColor:(CGFloat)gray alpha:(CGFloat)alpha { CGContextSetGrayStrokeColor(_context, gray, alpha); }
- (void)setInterpolationQuality:(CGInterpolationQuality)quality { CGContextSetInterpolationQuality(_context, quality); }
- (void)setLineCap:(CGLineCap)cap { CGContextSetLineCap(_context, cap); }
- (void)setLineDash:(id)enumerable phase:(CGFloat)phase
{
    int count;
    void *arr = enumerable_to_cgfloat(enumerable, &count);
    CGContextSetLineDash(_context, phase, arr, count);
    if (arr) {
        free(arr);
    }
}
- (void)setLineJoin:(CGLineJoin)join { CGContextSetLineJoin(_context, join); }
- (void)setLineWidth:(CGFloat)width { CGContextSetLineWidth(_context, width); }
- (void)setMiterLimit:(CGFloat)limit { CGContextSetMiterLimit(_context, limit); }
- (void)setPatternPhase:(CGSize)phase { CGContextSetPatternPhase(_context, phase); }
- (void)setRenderingIntent:(CGColorRenderingIntent)intent { CGContextSetRenderingIntent(_context, intent); }
- (void)setRGBFillColor:(CGRect)color { CGContextSetRGBFillColor(_context, color.origin.x, color.origin.y, color.size.width, color.size.height); }
- (void)setRGBStrokeColor:(CGRect)color { CGContextSetRGBStrokeColor(_context, color.origin.x, color.origin.y, color.size.width, color.size.height); }
- (void)setShadow:(CGSize)offset blur:(CGFloat)blur { CGContextSetShadow(_context, offset, blur); }
- (void)setShadowWithColor:(UIColor *)color offset:(CGSize)offset blur:(CGFloat)blur
{
    CGContextSetShadowWithColor(_context, offset, blur, [color CGColor]);
}
- (void)setShouldAntialias:(BOOL)val { CGContextSetShouldAntialias(_context, val); }
- (void)setShouldSmoothFonts:(BOOL)val { CGContextSetShouldSmoothFonts(_context, val); }
- (void)setShouldSubpixelPositionFonts:(BOOL)val { CGContextSetShouldSubpixelPositionFonts(_context, val); }
- (void)setShouldSubpixelQuantizeFonts:(BOOL)val { CGContextSetShouldSubpixelQuantizeFonts(_context, val); }
- (void)setStrokeColorSpace:(CGColorSpace *)colorspace { CGContextSetStrokeColorSpace(_context, [colorspace pointerValue]); }
- (void)setStrokeColorWithColor:(UIColor *)color { CGContextSetStrokeColorWithColor(_context, [color CGColor]); }
- (void)setStrokePattern:(CGPattern *)pattern color:(CGRect)color
{
    CGContextSetStrokeColorSpace(_context, [pattern colorspace]);
    CGContextSetStrokePattern(_context, [pattern pattern], &color);
}
- (void)setTextDrawingMode:(CGTextDrawingMode)mode { CGContextSetTextDrawingMode(_context, mode); }
- (void)setTextMatrix:(CGAffineTransform)t { CGContextSetTextMatrix(_context, t); }
- (void)setTextPosition:(CGPoint)p { CGContextSetTextPosition(_context, p.x, p.y); }
- (void)showGlyphs:(id)enumerable
{
    int count;
    void *arr = enumerable_to_unsigned_short(enumerable, &count);
    if (arr) {
        CGContextShowGlyphs(_context, arr, count);
        free(arr);
    }
}
- (void)showGlyphs:(id)enumerable atPoint:(CGPoint)p
{
    int count;
    void *arr = enumerable_to_unsigned_short(enumerable, &count);
    if (arr) {
        CGContextShowGlyphsAtPoint(_context, p.x, p.y, arr, count);
        free(arr);
    }
}
- (void)showText:(NSString *)str { CGContextShowText(_context, [str UTF8String], strlen([str UTF8String])); }
- (void)showText:(NSString *)str atPoint:(CGPoint)p { CGContextShowTextAtPoint(_context, p.x, p.y, [str UTF8String], strlen([str UTF8String])); }
- (void)strokeEllipseInRect:(CGRect)rect { CGContextStrokeEllipseInRect(_context, rect); }
- (void)strokePath { CGContextStrokePath(_context); }
- (void)strokeRect:(CGRect)rect { CGContextStrokeRect(_context, rect); }
- (void)strokeRect:(CGRect)rect withWidth:(CGFloat)width { CGContextStrokeRectWithWidth(_context, rect, width); }
- (void)translateCTM:(CGPoint)t { CGContextTranslateCTM(_context, t.x, t.y); }

