/*
 * TimelineView.j
 *
 * Created by daboe01 on August 23, 2016.
 * Copyright 2016, Your Company All rights reserved.
 */

// fixme: lane height: respect setAutoresizingMask:CPViewMinXMargin | CPViewMaxXMargin | CPViewMinYMargin | CPViewMaxYMargin
// fixme: flag for overlaying lanes
// support "ghost mode" for clipscale (flag: _shoudDrawClipscaled)
// draw vertical hairline during dragging
// fixme: make ruler position configurable with constants TLVRulerPositionAbove and TLVRulerPositionBelow (also flip clipscale amrkers in that case)

@import <Foundation/CPObject.j>
@import <CoreText/CGContextText.j>

TLVLaneStylePlain = 0;
TLVLaneValueInline = 1;
TLVLanePolygon = 2;
TLVLaneCircle = 4;
TLVLaneTimeRange = 8;
TLVLaneTimePoint = 16;
TLVLaneLaneLabel = 32;

TLVGranularityDay = 1;
TLVGranularityWeek = 2;
TLVGranularityMonth = 3;
TLVGranularityYear = 4;

var RULER_HEIGHT = 32;
var TICK_HEIGHT = 5;
var TIME_RANGE_DEFAULT_HEIGHT = 16;

TLVRulerMarkerLeft = 0;
TLVRulerMarkerRight = 1;

TLVRulerPositionAbove = 0;
TLVRulerPositionBelow = 1;

@implementation TLVTimeLane : CPView
{
    CPString     _laneIdentifier @accessors(property = laneIdentifier);
    CPString     _label @accessors(property = label);
    BOOL         _hasVerticalRuler @accessors(property = hasVerticalRuler);
    TimelineView _timelineView @accessors(property = timelineView);
    CPUInteger   _styleFlags @accessors(property=styleFlags);
    CPColor      _laneColor;
}

+ (CPArray) laneColorCodes
{
    return ["8DD3C7","BEBADA","FB8072","80B1D3","FDB462","B3DE69","FCCDE5","D9D9D9","BC80BD"]; // brewer.pal(10, "Set3") (RColorBrewer)
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
    var font = [CPFont systemFontOfSize:11];

    if(_styleFlags & TLVLaneLaneLabel && _label)
    {
        var labelSize = [_label sizeWithFont:font];
        var leftPoint=CGPointMake(_frame.size.width / 2 - labelSize.width / 2, 4);

        CGContextSelectFont(context, font);
        CGContextSetTextPosition(context, leftPoint.x, leftPoint.y);
        CGContextSetFillColor(context, _laneColor);
        CGContextSetStrokeColor(context, _laneColor);
        CGContextShowText(context, _label);
    }

    if(_styleFlags & TLVLanePolygon)
    {
        CGContextSetStrokeColor(context, _laneColor);

        var first=YES;
        for(var i = 0; i < n; i++) 
        {
            var o = myData[i];

            if(first)
            {   first=NO;
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

    if(_styleFlags & TLVLaneTimeRange)
    {
        CGContextSetFillColor(context, _laneColor);
        CGContextSetStrokeColor(context, _laneColor);

        for(var i = 0; i < n; i++) 
        {
            var o = myData[i];
            var myrect = CPMakeRect(o.x + 4, o.y + 4,  o.width - 4, TIME_RANGE_DEFAULT_HEIGHT - 4);
            CGContextStrokeRect(context, myrect);

            if (_styleFlags & TLVLaneValueInline && o.value)
            {
                var labelSize = [o.value sizeWithFont:font];
                var leftPoint=CGPointMake(o.x + o.width / 2 - labelSize.width / 2, o. y + TIME_RANGE_DEFAULT_HEIGHT / 2 + 1);

                CGContextSaveGState(context);
                CGContextSelectFont(context, font);
                CGContextSetTextPosition(context, leftPoint.x, leftPoint.y);
                CGContextSetFillColor(context, _laneColor);
                CGContextSetStrokeColor(context, _laneColor);
                CGContextShowText(context, o.value);
                CGContextRestoreGState(context);
            }
        }
    }
}


- (id)initWithFrame:(CGRect)aFrame
{
    if  (self = [super initWithFrame:aFrame])
    {
        _laneColor = [CPColor blueColor]
    }

    return self;
}

@end


@implementation TLVTimelineView : CPControl
{
    CPString        _timeKey @accessors(property = timeKey);
    CPString        _timeEndKey @accessors(property = timeEndKey);

    CPString        _durationKey @accessors(property = durationKey);
    CPString        _laneKey @accessors(property = laneKey);
    CPString        _valueKey @accessors(property = valueKey);
    BOOL            _showRuler @accessors(property = showRuler);
    CPDateFormatter _axisDateFormatter @accessors(property = axisDateFormatter);
    CPColor         _rulerTickColor @accessors(property = rulerTickColor);
    CPColor         _rulerLabelColor @accessors(property = rulerLabelColor);
    int             _rulerPosition @accessors(property = rulerPosition);
    CPDate          _clipScaleLowerDate @accessors(property = clipScaleLowerDate);
    CPDate          _clipScaleUpperDate @accessors(property = clipScaleUpperDate);
    BOOL            _shoudDrawClipscaled @accessors(property = clipScaleUpperDate);

    CPArray          _timeLanes;
    CGPoint          _selOriginOffset;
    TLVRulerMarkerID _draggingRulerMarker;
    CPRange          _range;
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
        _timeEndKey = 'date2';
        _valueKey = 'value';
        _laneKey = 'lane';
        _durationKey = 'duration';
        _clipScaleLowerDate = [CPDate distantPast];
        _clipScaleUpperDate = [CPDate distantFuture];

        _selOriginOffset = CGPointMake(0, 0);
    }

    return self;
}

- (void)addLane:(TimeLane)aTimeLane withIdentifier:(CPString)lane
{
    _timeLanes.push(aTimeLane);
    [aTimeLane setLaneIdentifier:lane];
    aTimeLane._laneColor = [CPColor colorWithHexString:[[aTimeLane class] laneColorCodes][_timeLanes.length - 1]];

    [aTimeLane setTimelineView:self];
    [self addSubview:aTimeLane];
    [self tile];
}

// this method returns an array with dictionaries that contain (among others) x and y properties (already appropriately scaled and in the lane coordinate system)
// <!> fixme: support scaling
// <!> fixme: move y scaling to the lane (the lanes is also responsible for drawing any y-axis rulers)
- (CPArray)dataForLane:(TimeLane)lane
{
    var inarray = [[self objectValue] filteredArrayUsingPredicate:[CPPredicate predicateWithFormat: _laneKey+" = %@", [lane laneIdentifier]]];
// fixme: clip by getDateRange
    var sortedarray = [inarray sortedArrayUsingDescriptors:[[[CPSortDescriptor alloc] initWithKey:_valueKey ascending:YES]]];
    var minY = [[sortedarray firstObject] valueForKey:_valueKey];
    var maxY = [[sortedarray lastObject] valueForKey:_valueKey];

    var outarray = [];
    var length = inarray.length;
    var pixelWidth = _frame.size.width;
    var pixelHeight = lane._frame.size.height;

    for (var i = 0; i < length; i++)
    {
       var xraw = [inarray[i] valueForKeyPath:_timeKey + ".timeIntervalSinceReferenceDate"];
       var x = ((xraw - _range.location) / _range.length) * pixelWidth;
       var yraw = [inarray[i] valueForKey:_valueKey];
       var y = pixelHeight - (((yraw - minY) / (maxY - minY)) * pixelHeight);
       var o = {"x":x, "y":y, "value": [inarray[i] valueForKey:_valueKey]};
       var xraw1 = [inarray[i] valueForKeyPath:_timeEndKey + @".timeIntervalSinceReferenceDate"];
       if (xraw1 !== null)
       {
           var x1 = ((xraw1 - _range.location) / _range.length) * pixelWidth;
           o.width = x1 - x;
           var baselineY = pixelHeight - TIME_RANGE_DEFAULT_HEIGHT - 5;
           o.y = baselineY;

           // stack overlapping rectangles
           var length_o = outarray.length;
           for (var j = 0; j < length_o; j++)
           {
               var existingRect = CGRectMake(outarray[j].x, outarray[j].y - TIME_RANGE_DEFAULT_HEIGHT, outarray[j].width, TIME_RANGE_DEFAULT_HEIGHT);
               var newRect = CGRectMake(o.x, o.y - TIME_RANGE_DEFAULT_HEIGHT, o.width, TIME_RANGE_DEFAULT_HEIGHT);

               if (CGRectIntersectsRect(newRect, existingRect) )
                   o.y -= TIME_RANGE_DEFAULT_HEIGHT - 2;
           }
       }
       outarray.push(o);
    }
    return outarray;
}

- (void)setClipScaleLowerDate:(CPDate)aDate
{
    _clipScaleLowerDate = aDate;
    [self tile];  // <!> fixme
}
- (void)setClipScaleUpperDate:(CPDate)aDate
{
    _clipScaleUpperDate = aDate;
    [self tile]; // <!> fixme
}
- (void)shoudDrawClipscaled:(BOOL)shouldDraw
{
    _shoudDrawClipscaled = shouldDraw;
    _range = [self getDateRange];
    [self setNeedsDisplay:YES]

    [_timeLanes makeObjectsPerformSelector:@selector(setNeedsDisplay:) withObject:YES];
}

// fixme: clip by _clipScaleLowerDate and _clipScaleUpperDate
- (CPRange)getDateRange
{
    var sortedarray = [[self objectValue] sortedArrayUsingDescriptors:[[[CPSortDescriptor alloc] initWithKey:_timeKey ascending:YES]]];
    var min = [[sortedarray firstObject] valueForKeyPath:_timeKey + @".timeIntervalSinceReferenceDate"];
    var max = [[sortedarray lastObject] valueForKeyPath:_timeKey + @".timeIntervalSinceReferenceDate"];

    var sortedarray = [[self objectValue] sortedArrayUsingDescriptors:[[[CPSortDescriptor alloc] initWithKey:_timeEndKey ascending:YES]]];
    var min2 = [[sortedarray firstObject] valueForKeyPath:_timeEndKey + @".timeIntervalSinceReferenceDate"];
    var max2 = [[sortedarray lastObject] valueForKeyPath:_timeEndKey + @".timeIntervalSinceReferenceDate"];

    if (min2 !== null)
        min = MIN(min, min2);

    if (max2 !== null)
        max = MAX(max, max2);

    if (_shoudDrawClipscaled)
    {
        min = MAX(min, [_clipScaleLowerDate timeIntervalSinceReferenceDate]);
        max = MIN(max, [_clipScaleUpperDate timeIntervalSinceReferenceDate]);
    }

    return CPMakeRange(min, max - min);
}

- (CPUInteger)dateGranularity
{
    var daysBetween= (_range.length / (60*60*24) ) + 1;

    if (daysBetween < 2)
       return TLVGranularityDay;
    if (daysBetween < 31 * 2)
       return TLVGranularityWeek;
    if (daysBetween < 365 * 2)
       return TLVGranularityMonth;

    return TLVGranularityYear;
}

- (TLVRulerMarkerID)_rulerMarkerUnderPoint:(CGPoint)point
{
    if (CGRectContainsPoint([self _rulerRectForID:TLVRulerMarkerLeft], point))
        return TLVRulerMarkerLeft;

    if (CGRectContainsPoint([self _rulerRectForID:TLVRulerMarkerRight], point))
        return TLVRulerMarkerRight;

    return CPNotFound;
}
- (CGRect)_rulerRectForID:(TLVRulerMarkerID)rulerMarker
{
    var effectiveDate;

	switch (rulerMarker)
	{
        case TLVRulerMarkerLeft:
            effectiveDate = _clipScaleLowerDate;
        break;
        case TLVRulerMarkerRight:
            effectiveDate = _clipScaleUpperDate;
        break;
	}
    var xraw = [effectiveDate timeIntervalSinceReferenceDate];
    var x = ((xraw - _range.location) / _range.length) * _frame.size.width;

    return CGRectMake(x, 0, 8, RULER_HEIGHT);
}

- (void)_moveRulerMarkerWithEvent:(CPEvent)event
{	var type = [event type];

	if (type == CPLeftMouseUp)
    {
		return;
    }
    else if (type == CPLeftMouseDragged)
    {
	    var mouseLocation = [self convertPoint:[event locationInWindow] fromView:nil];
        var effectiveDate;

	    switch (_draggingRulerMarker)
	    {
            case TLVRulerMarkerLeft:
                effectiveDate = _clipScaleLowerDate;
            break;
            case TLVRulerMarkerRight:
                effectiveDate = _clipScaleUpperDate;
            break;
        }

        if (effectiveDate)
        {
            var xraw = mouseLocation.x;
            xraw += _selOriginOffset.x;
            xraw /= _frame.size.width;

            var x =  xraw * _range.length + _range.location;

            if (x < _range.location)
                x = _range.location;
            if (x > CPMaxRange(_range))
                x = CPMaxRange(_range);

	        switch (_draggingRulerMarker)
	        {
                case TLVRulerMarkerLeft:
                    _clipScaleLowerDate = [CPDate dateWithTimeIntervalSinceReferenceDate:x];

                    if (_clipScaleLowerDate > _clipScaleUpperDate)
                        _clipScaleLowerDate = _clipScaleUpperDate
                break;
                case TLVRulerMarkerRight:
                    _clipScaleUpperDate = [CPDate dateWithTimeIntervalSinceReferenceDate:x];

                    if (_clipScaleUpperDate < _clipScaleLowerDate)
                        _clipScaleUpperDate = _clipScaleLowerDate;
                break;
            }
            [self setNeedsDisplay:YES]
        }
    }

	[CPApp setTarget:self selector:@selector(_moveRulerMarkerWithEvent:) forNextEventMatchingMask:CPLeftMouseDraggedMask | CPLeftMouseUpMask untilDate:nil inMode:nil dequeue:YES];
}

- (void)mouseDown:(CPEvent)event
{
	var mouseLocation = [self convertPoint:[event locationInWindow] fromView:nil];
    var rulerMarker = [self _rulerMarkerUnderPoint:mouseLocation];

	switch (rulerMarker)
	{
        case TLVRulerMarkerLeft:
        case TLVRulerMarkerRight:
            var markerFrame = [self _rulerRectForID:rulerMarker];
		    _selOriginOffset.x = markerFrame.origin.x - mouseLocation.x;
            _draggingRulerMarker = rulerMarker;
		    [self _moveRulerMarkerWithEvent:event];
        break;
	}
}

- (void)drawRect:(CGRect)rect
{
    if (!_showRuler)
        return;

    var drawRect = CGRectMake(0, 0, _frame.size.width, RULER_HEIGHT)

// <!> fixme: intersect drawRect with rect
    var ctx =  [[CPGraphicsContext currentContext] graphicsPort],
        font = [CPFont systemFontOfSize:11];    

    [[CPColor whiteColor] set];
    CGContextFillRect(ctx, drawRect);
    
    var granularity = [self dateGranularity];
    var pixelWidth = _frame.size.width;
    var numSteps;
    var secondsBetween;
    var axisDate = [CPDate dateWithTimeIntervalSinceReferenceDate:_range.location];

    switch (granularity)
    {
        case TLVGranularityDay:
            secondsBetween = 60;
        break;
        case TLVGranularityWeek:
            secondsBetween = (60*60*24);
            [_axisDateFormatter setDateFormat:@"dd.MM.YY"];
        break;
        case TLVGranularityMonth:
            secondsBetween = (60*60*24*7);
            [_axisDateFormatter setDateFormat:@"MM.YY"];
        break;
        default:
            [_axisDateFormatter setDateFormat:@"YYYY"];
   }
    numSteps = _range.length / secondsBetween;
    var gapBetween = pixelWidth / numSteps,
        lastRightLabelX = 0;

    // draw ticks and labels for ruler
    CGContextSetStrokeColor(ctx, _rulerTickColor);
    CGContextBeginPath(ctx);

    for (var x = 0; x < pixelWidth; x += gapBetween, axisDate = [axisDate dateByAddingTimeInterval:secondsBetween])
    {
        var label = [_axisDateFormatter stringFromDate:axisDate];
        var labelSize = [label sizeWithFont:font];
        var leftPoint=CGPointMake(x - labelSize.width / 2, RULER_HEIGHT- TICK_HEIGHT - labelSize.height);

        if (leftPoint.x < 0 || leftPoint.x + labelSize.width > pixelWidth || leftPoint.x < lastRightLabelX)
            continue;

        lastRightLabelX = leftPoint.x + labelSize.width + 4;

        CGContextMoveToPoint(ctx, x, RULER_HEIGHT- TICK_HEIGHT);
        CGContextAddLineToPoint(ctx, x, RULER_HEIGHT );
        CGContextSaveGState(ctx);
        CGContextSelectFont(ctx, font);
        CGContextSetTextPosition(ctx, leftPoint.x, leftPoint.y);
        CGContextSetFillColor(ctx, _rulerLabelColor);
        CGContextSetStrokeColor(ctx, _rulerLabelColor);
        CGContextShowText(ctx, label);
        CGContextRestoreGState(ctx);
    }
    CGContextSetLineWidth(ctx, 1);
    CGContextStrokePath(ctx);

    // draw clipscale markers
    if (_clipScaleLowerDate && _clipScaleLowerDate > [CPDate distantPast])
    {
         var leftRect = [self _rulerRectForID:TLVRulerMarkerLeft];
         var arrowsPath = [CPBezierPath bezierPath];
         [arrowsPath moveToPoint:CGPointMake(leftRect.origin.x, RULER_HEIGHT - 10)];
         [arrowsPath lineToPoint:CGPointMake(CGRectGetMaxX(leftRect), RULER_HEIGHT - 10)];
         [arrowsPath lineToPoint:CGPointMake(leftRect.origin.x, RULER_HEIGHT)];
         [arrowsPath closePath];
         CGContextSetFillColor(ctx, [[CPColor blueColor] set]);
         [arrowsPath fill];

    }
    if (_clipScaleUpperDate && _clipScaleUpperDate < [CPDate distantFuture])
    {
         var rightRect = [self _rulerRectForID:TLVRulerMarkerRight];
         var arrowsPath = [CPBezierPath bezierPath];
         [arrowsPath moveToPoint:CGPointMake(CGRectGetMaxX(rightRect), RULER_HEIGHT - 10)];
         [arrowsPath lineToPoint:CGPointMake(rightRect.origin.x, RULER_HEIGHT - 10)];
         [arrowsPath lineToPoint:CGPointMake(CGRectGetMaxX(rightRect), RULER_HEIGHT)];
         [arrowsPath closePath];
         CGContextSetFillColor(ctx, [[CPColor blueColor] set]);
         [arrowsPath fill];
    }
}

- (void)tile
{
    var laneCount = [_timeLanes count],
        currentOrigin = CGPointMake(0, (_showRuler? RULER_HEIGHT : 0)),
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
    _range = [self getDateRange];
    [self tile];
}
@end

/*
@implementation GSMarkupTagTimelineView:GSMarkupTagView
+ (CPString) tagName
{    return @"timelineView";
}

+ (Class) platformObjectClass
{    return [TLVTimelineView class];
}
@end
*/