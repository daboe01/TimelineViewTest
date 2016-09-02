/*
 * TimelineView.j
 *
 * Created by daboe01 on August 23, 2016.
 * Copyright 2016, Your Company All rights reserved.
 */

@import <Foundation/CPObject.j>
@import <CoreText/CGContextText.j>

TLVLaneStylePlain = 0;
TLVLaneValueInline = 1;
TLVLanePolygon = 2;
TLVLaneCircle = 4;
TLVLaneTimeRange = 8;
TLVLaneTimeArrow = 16;

TLVGranularityDay = 1;
TLVGranularityWeek = 2;
TLVGranularityMonth = 3;
TLVGranularityMonthYear = 4;
TLVGranularityYear = 5;

var RULER_HEIGHT = 32;
var TICK_HEIGHT = 5;
var RULER_TICK_PADDING = 5;
// <!> remove padding by check whether label fits
// <!> also prevent overplotting of labels if with is to high

TLVColorCodes=["8DD3C7","BEBADA","FB8072","80B1D3","FDB462","B3DE69","FCCDE5","D9D9D9","BC80BD"]; // brewer.pal(10, "Set3") (RColorBrewer)

@implementation TimeLane : CPView
{
    CPString     _laneIdentifier @accessors(property = laneIdentifier);
    BOOL         _hasVerticalRuler @accessors(property = hasVerticalRuler);
    TimelineView _timelineView @accessors(property = timelineView);
    CPUInteger   _styleFlags @accessors(property=styleFlags);
}

- (void)addStyleFlags:(CPUInteger)flagsToAdd
{
    _styleFlags |= flagsToAdd
}

- (void)removeStyleFlags:(CPUInteger)flagsToRemove
{
    _styleFlags &= ~flagsToRemove
}

- (void)drawRect:(CGRect)rect
{
    var context = [[CPGraphicsContext currentContext] graphicsPort];
    var myData = [_timelineView dataForLane:self];
    var n =  [myData count];

    if(_styleFlags & TLVLanePolygon)
    {
        var first=YES;
        for(var i = 0; i < n; i++) 
        {
            var o = myData[i];

            if(first)
            {   first=NO;
                CGContextSetStrokeColor(context, [CPColor blueColor]);
                CGContextBeginPath(context);
                CGContextMoveToPoint(context, o.x, o.y);
            } else
                CGContextAddLineToPoint(context, o.x, o.y);

        }
        CGContextSetLineWidth(context, 1);
        CGContextStrokePath(context);
    }

    if(_styleFlags & TLVLaneCircle)
    {
        for(var i = 0; i < n; i++) 
        {
            var o = myData[i];
            var myrect = CPMakeRect(o.x - 2, o.y - 2,  4, 4);
            CGContextStrokeEllipseInRect(context, myrect);
        }
    }

}


- (id)initWithFrame:(CGRect)aFrame
{
    if  (self = [super initWithFrame:aFrame])
    {
        _styleFlags |= TLVLanePolygon;
    }

    return self;
}

@end


@implementation TimelineView : CPControl
{
    CPString        _timeKey @accessors(property = timeKey);
    CPString        _laneKey @accessors(property = laneKey);
    CPString        _valueKey @accessors(property = valueKey);
    BOOL            _showRuler @accessors(property = showRuler);
    CPDateFormatter _axisDateFormatter @accessors(property = axisDateFormatter);
    CPColor         _rulerTickColor @accessors(property = rulerTickColor);
    CPColor         _rulerLabelColor @accessors(property = rulerLabelColor);
    float           _timeScale @accessors(property = timeScale);

    CPArray         _timeLanes;
}

- (id)initWithFrame:(CGRect)aFrame
{   if  (self = [super initWithFrame:aFrame])
    {
        _timeLanes = @[];
        _showRuler = YES;
        _axisDateFormatter = [CPDateFormatter new];
        [_axisDateFormatter setDateStyle:CPDateFormatterShortStyle];
        _rulerTickColor = [CPColor grayColor];
        _rulerLabelColor = [CPColor grayColor];
        _timeKey = 'date';
        _valueKey = 'value';
        _laneKey = 'lane';
    }

    return self;
}

- (void)addLane:(TimeLane)aTimeLane withIdentifier:(CPString)laneID
{
    _timeLanes.push(aTimeLane);
    [aTimeLane setLaneIdentifier:laneID];
    [aTimeLane setTimelineView:self];
    [self addSubview:aTimeLane];
    [self tile];
}

// this method returns an array with dictionaries that contain (among others) x and y properties (already appropriately scaled and in the lane coordinate system)
// <!> fixme: support scaling
- (CPArray)dataForLane:(TimeLane)laneID
{
    var inarray = [[self objectValue] filteredArrayUsingPredicate:[CPPredicate predicateWithFormat: _laneKey+" = %@", [laneID laneIdentifier]]];
    var sortedarray = [inarray sortedArrayUsingDescriptors:[[[CPSortDescriptor alloc] initWithKey:_valueKey ascending:YES]]];
    var minY = [[sortedarray firstObject] valueForKey:_valueKey];
    var maxY = [[sortedarray lastObject] valueForKey:_valueKey];

    var outarray = [];
    var length = inarray.length;
    var range = [self getDateRange];
    var pixelWidth = _frame.size.width;
    var pixelHeight = _frame.size.height;

    for (var i = 0; i < length; i++)
    {
       var xraw = [inarray[i] valueForKeyPath:_timeKey + @".timeIntervalSinceReferenceDate"];
       var x = ((xraw - range.location) / range.length) * pixelWidth;
       var yraw = [inarray[i] valueForKey:_valueKey];
       var y = pixelHeight - (((yraw - minY) / (maxY - minY)) * pixelHeight);
       outarray.push({"x":x, "y":y});
    }

    return outarray;
}

- (CPRange)getDateRange
{
    var sortedarray = [[self objectValue] sortedArrayUsingDescriptors:[[[CPSortDescriptor alloc] initWithKey:_timeKey ascending:YES]]];
    var min = [[sortedarray firstObject] valueForKeyPath:_timeKey + @".timeIntervalSinceReferenceDate"];
    var max = [[sortedarray lastObject] valueForKeyPath:_timeKey + @".timeIntervalSinceReferenceDate"];

    return CPMakeRange(min, max - min);
}

- (CPUInteger)dateGranularity
{
    var range = [self getDateRange]
    var daysBetween= (range.length / (60*60*24) ) + 1;

    if (daysBetween < 2)
       return TLVGranularityDay;
    if (daysBetween < 8)
       return TLVGranularityWeek;
    if (daysBetween < 32)
       return TLVGranularityMonth;
    if (daysBetween < 366)
       return TLVGranularityMonthYear;

    return TLVGranularityYear;
}

- (void)drawRect:(CGRect)rect
{
    if (!_showRuler)
        return;

    var drawRect = CGRectMake(0, 0, _frame.size.width, RULER_HEIGHT)

// <!> fixme: intersect drawRect with rect
    var ctx =  [[CPGraphicsContext currentContext] graphicsPort],
        font = [CPFont systemFontOfSize:11],
        zeroLocation, firstVisibleLocation, lastVisibleLocation;
    

    [[CPColor whiteColor] set];
    CGContextFillRect(ctx, drawRect);
    
    var range = [self getDateRange];
    var granularity = [self dateGranularity];
    var pixelWidth = _frame.size.width;
    var numSteps;
    var secondsBetween;
    var axisDate = [CPDate dateWithTimeIntervalSinceReferenceDate:range.location];

    switch (granularity)
    {
        case TLVGranularityDay:
            secondsBetween = 60;
        break;
        case TLVGranularityWeek:
            secondsBetween = (60*60*24);
        break;
    }
    numSteps = range.length / secondsBetween;
    var gapBetween = pixelWidth / numSteps;

    // draw ticks and labels for ruler
    CGContextSetStrokeColor(ctx, _rulerTickColor);
    CGContextBeginPath(ctx);

    for (var x = 0; x < pixelWidth; x += gapBetween, axisDate = [axisDate dateByAddingTimeInterval:secondsBetween])
    {
        if (x < RULER_TICK_PADDING || x > pixelWidth - RULER_TICK_PADDING)
            continue;

        CGContextMoveToPoint(ctx, x, RULER_HEIGHT- TICK_HEIGHT);
        CGContextAddLineToPoint(ctx, x, RULER_HEIGHT );
        var label = [_axisDateFormatter stringFromDate:axisDate];
        var labelSize = [label sizeWithFont:font];
        CGContextSaveGState(ctx);
        CGContextSelectFont(ctx, font);
        var midPoint=CGPointMake(x - labelSize.width / 2, RULER_HEIGHT- TICK_HEIGHT - labelSize.height);
        CGContextSetTextPosition(ctx, midPoint.x, midPoint.y);
        CGContextSetFillColor(ctx, _rulerLabelColor);
        CGContextSetStrokeColor(ctx, _rulerLabelColor);
        CGContextShowText(ctx, label);
        CGContextRestoreGState(ctx);
    }
    CGContextSetLineWidth(ctx, 1);
    CGContextStrokePath(ctx);
}

- (void)tile
{
    var laneCount = [_timeLanes count],
        currentOrigin = CPPointMake(0, (_showRuler? RULER_HEIGHT : 0)),
        laneHeight = (_frame.size.height - (_showRuler? RULER_HEIGHT : 0)) / laneCount;

    for (var i = 0; i < laneCount; i++)
    {
        var currentLane = [_timeLanes objectAtIndex:i];
        [currentLane setFrameOrigin:currentOrigin];
        [currentLane setFrameSize:CPMakeSize(self._frame.size.width, laneHeight)];
        currentOrigin.y += laneHeight;
    }
}
// the array has to contain KVC-compliant objects that have CPDates stored in the key specified by timeKey
- (void)setObjectValue:(CPArray)someValue
{
    [super setObjectValue:someValue];
    [self tile];
}
@end

/*
@implementation GSMarkupTagAnnotatedImageView:GSMarkupTagView
+ (CPString) tagName
{    return @"timelineView";
}

+ (Class) platformObjectClass
{    return [TimelineView class];
}
@end
*/