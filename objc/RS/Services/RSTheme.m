#import "RSTheme.h"

@implementation RSTheme

+ (UIColor *)colorFromHex:(NSString *)hex {
    NSString *s = [[hex stringByReplacingOccurrencesOfString:@"#" withString:@""]
                   stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    unsigned long long v = 0;
    NSScanner *sc = [NSScanner scannerWithString:s];
    [sc scanHexLongLong:&v];
    CGFloat r, g, b, a = 1.0;
    if ([s length] == 8) {
        r = ((v >> 24) & 0xFF) / 255.0;
        g = ((v >> 16) & 0xFF) / 255.0;
        b = ((v >> 8)  & 0xFF) / 255.0;
        a = (v & 0xFF) / 255.0;
    } else {
        r = ((v >> 16) & 0xFF) / 255.0;
        g = ((v >> 8)  & 0xFF) / 255.0;
        b = (v & 0xFF) / 255.0;
    }
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

+ (UIColor *)accent  { return [self colorFromHex:@"5B7CFA"]; }
+ (UIColor *)accent2 { return [self colorFromHex:@"9B6BFF"]; }
+ (UIColor *)bg      { return [self colorFromHex:@"0B0D14"]; }
+ (UIColor *)card    { return [self colorFromHex:@"161A26"]; }
+ (UIColor *)card2   { return [self colorFromHex:@"1E2333"]; }
+ (UIColor *)textSub { return [self colorFromHex:@"8A90A6"]; }

+ (NSArray<UIColor *> *)paletteForSeed:(NSString *)seed {
    NSArray<NSArray<NSString *> *> *palettes = @[
        @[@"5B7CFA", @"9B6BFF"],
        @[@"FF6B6B", @"FFA36B"],
        @[@"22C1C3", @"4FACFE"],
        @[@"F857A6", @"FF5858"],
        @[@"43E97B", @"38F9D7"],
        @[@"FA709A", @"FEE140"],
        @[@"667EEA", @"764BA2"],
        @[@"00C6FF", @"0072FF"],
        @[@"F7971E", @"FFD200"],
        @[@"EE0979", @"FF6A00"],
    ];
    unsigned long h = 5381;
    const char *utf8 = [seed UTF8String] ?: "";
    for (const char *p = utf8; *p; p++) {
        h = ((h << 5) + h) + (unsigned char)*p;
    }
    NSArray<NSString *> *pair = palettes[h % palettes.count];
    return @[[self colorFromHex:pair[0]], [self colorFromHex:pair[1]]];
}

+ (CAGradientLayer *)gradientLayerWithFrame:(CGRect)frame {
    CAGradientLayer *g = [CAGradientLayer layer];
    g.frame = frame;
    g.colors = @[(id)[self accent].CGColor, (id)[self accent2].CGColor];
    g.startPoint = CGPointMake(0, 0);
    g.endPoint = CGPointMake(1, 1);
    return g;
}

+ (CAGradientLayer *)gradientForSeed:(NSString *)seed frame:(CGRect)frame {
    NSArray<UIColor *> *colors = [self paletteForSeed:seed];
    CAGradientLayer *g = [CAGradientLayer layer];
    g.frame = frame;
    g.colors = @[(id)colors[0].CGColor, (id)colors[1].CGColor];
    g.startPoint = CGPointMake(0, 0);
    g.endPoint = CGPointMake(1, 1);
    return g;
}

@end
