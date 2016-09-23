/*
 * TimelineView.j
 *
 * Created by daboe01 on August 23, 2016.
 * Copyright 2016, Your Company All rights reserved.
 */

// support single points in time
// fixme: lane height tiling with horizontal split view
// fixme: flag for overlaying lanes
// draw vertical hairline during dragging
// fixme: test TLVRulerPositionBelow (flip clipscale markers here)

@import <Foundation/CPObject.j>

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
var TICK_WIDTH = 4;
var TIME_RANGE_DEFAULT_HEIGHT = 16;
var MARKER_WIDTH = 8;
var VRULER_WIDTH = 50;

var HUGE_NUMBER = 9007199254740990

TLVRulerMarkerLeft = 0;
TLVRulerMarkerRight = 1;

TLVRulerPositionNone = 0;
TLVRulerPositionAbove = 1;
TLVRulerPositionBelow = 2;

@implementation TLVTimeLane : CPView
{
    CPString     _laneIdentifier @accessors(property = laneIdentifier);
    CPString     _label @accessors(property = label);
    BOOL         _hasVerticalRuler @accessors(property = hasVerticalRuler);
    TimelineView _timelineView @accessors(property = timelineView);
    CPUInteger   _styleFlags @accessors(property=styleFlags);
    CPColor      _laneColor;

    // private housekeeping stuff
    CPRange      _valueRange;
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

-(CPFloat)_roundValue:(CPFloat)aValue
{
    if (!aValue)
        return 0;


    var pow10x = Math.pow(10, Math.ceil(Math.log10(Math.abs(aValue)) - 1));
    return Math.ceil(aValue / pow10x) * pow10x;

}
- (void)_drawVerticalRuler
{
    if (!_valueRange)
        return;

    var context = [[CPGraphicsContext currentContext] graphicsPort];
    var pixelHeight = _frame.size.height;
    var font = [CPFont systemFontOfSize:11];

    var tickCount = Math.ceil(pixelHeight / 30);
    var tickSize = _valueRange.length / (tickCount - 1);
    var roundedTickRange = [self _roundValue:tickSize];

    var gapBetween = pixelHeight * (roundedTickRange / _valueRange.length);
    var yLabel = [self _roundValue:CPMaxRange(_valueRange)];

    [[CPColor whiteColor] set];
    CGContextFillRect(context, CGRectMake( 0, 0, VRULER_WIDTH, _frame.size.height));

    CGContextSetStrokeColor(context, _timelineView._rulerTickColor);

    CGContextBeginPath(context);
    CGContextMoveToPoint(context, VRULER_WIDTH, 0);
    CGContextAddLineToPoint(context, VRULER_WIDTH, pixelHeight);

    for (var y = pixelHeight * ((CPMaxRange(_valueRange) - yLabel) / _valueRange.length); y < pixelHeight; y += gapBetween, yLabel -= roundedTickRange)
    {
        if (y < 1)
            continue;

        var label = [CPString stringWithFormat:"%d", yLabel];
        var labelSize = [label sizeWithFont:font];
        var leftPoint = CGPointMake(VRULER_WIDTH - labelSize.width - TICK_WIDTH, y );

        CGContextMoveToPoint(context, VRULER_WIDTH - TICK_WIDTH, leftPoint.y);
        CGContextAddLineToPoint(context, VRULER_WIDTH, leftPoint.y);
        CGContextSaveGState(context);
        CGContextSelectFont(context, font);
        CGContextSetTextPosition(context, leftPoint.x, leftPoint.y );
        CGContextSetFillColor(context, _timelineView._rulerLabelColor);
        CGContextSetStrokeColor(context, _timelineView._rulerLabelColor);
        CGContextShowText(context, label);
        CGContextRestoreGState(context);
    }
    CGContextSetLineWidth(context, 1);
    CGContextStrokePath(context);

    // draw ruler title
    if(_styleFlags & TLVLaneLaneLabel && _label)
    {
        var labelSize = [_label sizeWithFont:font];
        var leftPoint=CGPointMake(_frame.size.width / 2 - labelSize.width / 2, 4);

        CGContextSaveGState(context);
        CGContextSetFillColor(context, _timelineView._rulerLabelColor);
        CGContextSetStrokeColor(context, _timelineView._rulerLabelColor);
        // CGContextSetTextMatrix(context, CGAffineTransformMakeRotation((-0.5) * Math.PI));
        context.translate(labelSize.height / 2, _frame.size.height / 2 + labelSize.width / 2);
        context.rotate((-0.5) * Math.PI);
        CGContextShowTextAtPoint(context, 0, 0,  _label);
        CGContextRestoreGState(context);
    }
}

- (void)drawRect:(CGRect)rect
{
    var context = [[CPGraphicsContext currentContext] graphicsPort];
    var myData = [_timelineView dataForLane:self];
    var n =  [myData count];
    var font = [CPFont systemFontOfSize:11];

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
                var leftPoint = CGPointMake(o.x + o.width / 2 - labelSize.width / 2, o.y + TIME_RANGE_DEFAULT_HEIGHT / 2 + (TIME_RANGE_DEFAULT_HEIGHT - labelSize.height) / 2);
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

    if (_hasVerticalRuler)
        [self _drawVerticalRuler]
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

@implementation CPDate(shortDescription)
- (CPString)shortDescription
{
    return [CPString stringWithFormat:@"%04d-%02d-%02d", self.getFullYear(), self.getMonth() + 1, self.getDate()];
}
- (id)initWithShortString:(CPString)description
{
    if (!description)
        return nil;

    var format = /(\d{4})-(\d{2})-(\d{2})/,
        d = description.match(new RegExp(format));
    return new Date(d[1], d[2] - 1, d[3]);
}
@end

@implementation CPObject(_DateCasting)

- (CPDate)dateValueForKeyPath:(CPString)aKey
{
    var val = [self valueForKeyPath:aKey];

    if (![val isKindOfClass:[CPDate class]])
    {
        return [[CPDate alloc] initWithShortString:val];
    }

    return val;
}

@end

@implementation TLVTimelineView : CPControl
{
    CPString        _timeKey @accessors(property = timeKey);
    CPString        _timeEndKey @accessors(property = timeEndKey);

    CPString        _durationKey @accessors(property = durationKey);
    CPString        _laneKey @accessors(property = laneKey);
    CPString        _valueKey @accessors(property = valueKey);

    CPDateFormatter _axisDateFormatter @accessors(property = axisDateFormatter);
    CPColor         _rulerTickColor @accessors(property = rulerTickColor);
    CPColor         _rulerLabelColor @accessors(property = rulerLabelColor);
    int             _rulerPosition @accessors(property = rulerPosition);
    CPDate          _clipScaleLowerDate @accessors(property = clipScaleLowerDate);
    CPDate          _clipScaleUpperDate @accessors(property = clipScaleUpperDate);
    BOOL            _shoudDrawClipscaled @accessors(property = clipScaleUpperDate);
    CPUInteger      _rulerPosition @accessors(property = rulerPosition);
    BOOL            _hideVerticalRulers @accessors(property = hideVerticalRulers);

    // private housekeeping stuff
    CPRect           _rulerRect;
    CPArray          _timeLanes;
    CGPoint          _selOriginOffset;
    TLVRulerMarkerID _draggingRulerMarker;
    CPRange          _range;
}

- (id)initWithFrame:(CGRect)aFrame
{   if  (self = [super initWithFrame:aFrame])
    {
        _timeLanes = @[];
        _axisDateFormatter = [CPDateFormatter new];
        [_axisDateFormatter setDateStyle:CPDateFormatterShortStyle];
        _rulerTickColor = [CPColor grayColor];
        _rulerLabelColor = [CPColor grayColor];
        _timeKey = 'date';
        _timeEndKey = nil;
        _valueKey = 'value';
        _laneKey = 'lane';
        _durationKey = 'duration';
        _clipScaleLowerDate = [CPDate distantPast];
        _clipScaleUpperDate = [CPDate distantFuture];

        _selOriginOffset = CGPointMake(0, 0);

        [self setRulerPosition:TLVRulerPositionAbove];
    }

    return self;
}
- (void)setFrameSize:(CGSize)aSize
{
    [super setFrameSize:aSize];
    [self _recalcRulerRect];
    [self setNeedsDisplay:YES];
    [self tile]
}
- (void)_recalcRulerRect
{
    switch (_rulerPosition)
    {
        case TLVRulerPositionAbove:
            _rulerRect = CGRectMake(_hideVerticalRulers? 0:VRULER_WIDTH, 0, _frame.size.width, RULER_HEIGHT);
        break;
        case TLVRulerPositionBelow:
            _rulerRect = CGRectMake(_hideVerticalRulers? 0:VRULER_WIDTH, _frame.size.height - RULER_HEIGHT, _frame.size.width, RULER_HEIGHT);
        break;
        default:
            _rulerRect = CGRectMake(0, 0, 0, 0);
    }
}

- (void)setRulerPosition:(CPUInteger)aPos
{
    _rulerPosition = TLVRulerPositionAbove;
    [self _recalcRulerRect];
    [self setNeedsDisplay:YES];
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
// <!> fixme: move y scaling to the lane (the lanes is also responsible for drawing any y-axis rulers)
- (CPArray)dataForLane:(TimeLane)lane
{
    var inarray = _laneKey? [[self objectValue] filteredArrayUsingPredicate:[CPPredicate predicateWithFormat: _laneKey+" = %@", [lane laneIdentifier]]] : [self objectValue];

    if (![inarray respondsToSelector:@selector(sortedArrayUsingDescriptors:)])
        return;

// fixme: clip by getDateRange
    var sortedarray = [inarray sortedArrayUsingDescriptors:[[[CPSortDescriptor alloc] initWithKey:_valueKey ascending:YES]]];


    var outarray = [];
    var length = inarray.length;
    var pixelWidth = _rulerRect.size.width - (_hideVerticalRulers? 0:VRULER_WIDTH);
    var pixelHeight = lane._frame.size.height;

    var maxY = HUGE_NUMBER * (-1),
        minY = HUGE_NUMBER;

    for (var i = 0; i < length; i++)
    {   var val = [inarray[i] valueForKey:_valueKey];
        minY = MIN(minY, val);
        maxY = MAX(maxY, val);
    }
    lane._valueRange = CPMakeRange(minY, maxY - minY)

    for (var i = 0; i < length; i++)
    {
       var xraw = [[inarray[i] dateValueForKeyPath:_timeKey] timeIntervalSinceReferenceDate];
       var x = ((xraw - _range.location) / _range.length) * pixelWidth + (_hideVerticalRulers? 0:VRULER_WIDTH);
       var yraw = [inarray[i] valueForKey:_valueKey];
       var y = pixelHeight - (((yraw - minY) / (maxY - minY)) * pixelHeight);
       var o = {"x":x, "y":y, "value": [inarray[i] valueForKey:_valueKey]};

       if (_timeEndKey)
       {
           var xraw1 = [[inarray[i] dateValueForKeyPath:_timeEndKey]  timeIntervalSinceReferenceDate];
           if (xraw1 !== null)
           {
               var x1 = ((xraw1 - _range.location) / _range.length) * pixelWidth + (_hideVerticalRulers? 0:VRULER_WIDTH);
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
       }
       outarray.push(o);
    }

    var maxY = HUGE_NUMBER * (-1),
        minY = HUGE_NUMBER,
        length = outarray.length;

    lane._naturalHeight = 0;

    for (var i = 0; i < length; i++)
    {   var val = outarray[i];
        if (val.width !== undefined)
        {   minY = MIN(minY, val.y);
            maxY = MAX(maxY, val.y);
            lane._naturalHeight = maxY - minY + TIME_RANGE_DEFAULT_HEIGHT + 4;
        }
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
    if (![[self objectValue] respondsToSelector:@selector(sortedArrayUsingDescriptors:)])
        return nil;

    var sortedarray = [[self objectValue] sortedArrayUsingDescriptors:[[[CPSortDescriptor alloc] initWithKey:_timeKey ascending:YES]]];
    var min = [[[sortedarray firstObject] dateValueForKeyPath:_timeKey] timeIntervalSinceReferenceDate];
    var max = [[[sortedarray lastObject] dateValueForKeyPath:_timeKey]  timeIntervalSinceReferenceDate];

    if (_timeEndKey)
    {
        var sortedarray = [[self objectValue] sortedArrayUsingDescriptors:[[[CPSortDescriptor alloc] initWithKey:_timeEndKey ascending:YES]]];
        var min2 = [[[sortedarray firstObject] dateValueForKeyPath:_timeEndKey] timeIntervalSinceReferenceDate];
        var max2 = [[[sortedarray lastObject] dateValueForKeyPath:_timeEndKey] timeIntervalSinceReferenceDate];

        if (min2 !== null)
            min = MIN(min, min2);

        if (max2 !== null)
            max = MAX(max, max2);
    }

    if (_shoudDrawClipscaled)
    {
        min = MAX(min, [_clipScaleLowerDate timeIntervalSinceReferenceDate]);
        max = MIN(max, [_clipScaleUpperDate timeIntervalSinceReferenceDate]);
    }

    return CPMakeRange(min, max - min);
}

- (CPUInteger)dateGranularity
{

    if (!_range)
        return null;

    var daysBetween= (_range.length / (60*60*24) ) + 1;

    if (daysBetween < 2)
       return TLVGranularityDay;
    if (daysBetween < 31 * 6)
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
    var x = ((xraw - _range.location) / _range.length) * _rulerRect.size.width;

    var rect = CGRectMake(x + (_hideVerticalRulers? 0:VRULER_WIDTH), _rulerRect.origin.y, MARKER_WIDTH, _rulerRect.size.height);

	switch (rulerMarker)
	{
        case TLVRulerMarkerRight:
            rect.origin.x -= MARKER_WIDTH;
        break;
	}

    return rect;
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
            var xraw = mouseLocation.x - (_hideVerticalRulers? 0:VRULER_WIDTH);
            xraw += _selOriginOffset.x;
            xraw /= _rulerRect.size.width;

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
            [self setNeedsDisplay:YES];
            [self autoscroll:event];
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
		    _selOriginOffset.x = markerFrame.origin.x - mouseLocation.x + (rulerMarker == TLVRulerMarkerRight? MARKER_WIDTH : 0);
            _draggingRulerMarker = rulerMarker;
		    [self _moveRulerMarkerWithEvent:event];
        break;
        default:
            var xraw = mouseLocation.x - (_hideVerticalRulers? 0:VRULER_WIDTH);
            xraw /= _rulerRect.size.width;
            var x =  xraw * _range.length + _range.location;

            if (mouseLocation.x < _rulerRect.size.width / 2 && _clipScaleLowerDate <= [CPDate distantPast])
            {
                _clipScaleLowerDate = [CPDate dateWithTimeIntervalSinceReferenceDate:x];
                _draggingRulerMarker = TLVRulerMarkerLeft;
                [self setNeedsDisplay:YES];
		        [self _moveRulerMarkerWithEvent:event];
            } else if (mouseLocation.x >= _rulerRect.size.width / 2 && _clipScaleUpperDate >= [CPDate distantPast])
            {
                _clipScaleUpperDate = [CPDate dateWithTimeIntervalSinceReferenceDate:x];
                _draggingRulerMarker = TLVRulerMarkerRight;
                [self setNeedsDisplay:YES];
		        [self _moveRulerMarkerWithEvent:event];
            }
	}
}

- (void)drawRect:(CGRect)rect
{
    if (_rulerPosition === TLVRulerPositionNone)
        return;

// <!> fixme: intersect _rulerRect with rect
    var ctx =  [[CPGraphicsContext currentContext] graphicsPort],
        font = [CPFont systemFontOfSize:11];    

    [[CPColor whiteColor] set];
    CGContextFillRect(ctx, _rulerRect);
    
    var granularity = [self dateGranularity];

    if (granularity === null)
        return;

    var pixelWidth = _rulerRect.size.width - (_hideVerticalRulers? 0:VRULER_WIDTH);
    var secondsBetween;
    var axisDate = [CPDate dateWithTimeIntervalSinceReferenceDate:_range.location];

    switch (granularity)
    {
        case TLVGranularityDay:
            secondsBetween = 60;
            [_axisDateFormatter setDateFormat:@"hh:mm:ss"];
        break;
        case TLVGranularityWeek:
            secondsBetween = (60*60*24);
            [_axisDateFormatter setDateFormat:@"dd.MM.YY"];
        break;
        case TLVGranularityMonth:
            secondsBetween = (60 * 60 * 24 * 31);
            [_axisDateFormatter setDateFormat:@"MM.YY"];
        break;
        default:
            secondsBetween = (60 * 60 * 24 * 366);
            [_axisDateFormatter setDateFormat:@"YYYY"];

    }
    var numSteps = _range.length / secondsBetween;
    var gapBetween = pixelWidth / numSteps,
        lastRightLabelX = 0;

    // draw ticks and labels for ruler
    CGContextSetStrokeColor(ctx, _rulerTickColor);

    CGContextBeginPath(ctx);
    CGContextMoveToPoint(ctx, (_hideVerticalRulers? 0:VRULER_WIDTH), CGRectGetMaxY(_rulerRect));
    CGContextAddLineToPoint(ctx, _frame.size.width, CGRectGetMaxY(_rulerRect));

    for (var x = _hideVerticalRulers? 0:VRULER_WIDTH; x < pixelWidth; x += gapBetween, axisDate = [axisDate dateByAddingTimeInterval:secondsBetween])
    {
        var label = [_axisDateFormatter stringFromDate:axisDate];
        var labelSize = [label sizeWithFont:font];
        var leftPoint = CGPointMake(x - labelSize.width / 2, CGRectGetMaxY(_rulerRect) - TICK_HEIGHT - labelSize.height);

        if (leftPoint.x < _rulerRect.origin.x || leftPoint.x + labelSize.width > pixelWidth + (_hideVerticalRulers? 0:VRULER_WIDTH) || leftPoint.x < lastRightLabelX)
            continue;

        lastRightLabelX = leftPoint.x + labelSize.width + 4;

        CGContextMoveToPoint(ctx, x, CGRectGetMaxY(_rulerRect) - TICK_HEIGHT);
        CGContextAddLineToPoint(ctx, x, CGRectGetMaxY(_rulerRect));
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
         [arrowsPath moveToPoint:CGPointMake(leftRect.origin.x, CGRectGetMaxY(_rulerRect) - 10)];
         [arrowsPath lineToPoint:CGPointMake(CGRectGetMaxX(leftRect), CGRectGetMaxY(_rulerRect) - 10)];
         [arrowsPath lineToPoint:CGPointMake(leftRect.origin.x, CGRectGetMaxY(_rulerRect))];
         [arrowsPath closePath];
         CGContextSetFillColor(ctx, [[CPColor blueColor] set]);
         [arrowsPath fill];

    }
    if (_clipScaleUpperDate && _clipScaleUpperDate < [CPDate distantFuture])
    {
         var rightRect = [self _rulerRectForID:TLVRulerMarkerRight];
         var arrowsPath = [CPBezierPath bezierPath];
         [arrowsPath moveToPoint:CGPointMake(CGRectGetMaxX(rightRect), CGRectGetMaxY(_rulerRect) - 10)];
         [arrowsPath lineToPoint:CGPointMake(rightRect.origin.x, CGRectGetMaxY(_rulerRect) - 10)];
         [arrowsPath lineToPoint:CGPointMake(CGRectGetMaxX(rightRect), CGRectGetMaxY(_rulerRect))];
         [arrowsPath closePath];
         CGContextSetFillColor(ctx, [[CPColor blueColor] set]);
         [arrowsPath fill];
    }
}

- (void)tile
{
    if (!_rulerRect)
        return; 

   var laneCount = [_timeLanes count],
       currentOrigin = CGPointMake(0, (_rulerPosition == TLVRulerPositionAbove? CGRectGetMaxY(_rulerRect) : 0)),
       totalHeight = _frame.size.height,
       fixedCount = 0;

    for (var i = 0; i < laneCount; i++)
    {
        var currentLane = [_timeLanes objectAtIndex:i];

        // this is expensive. run this only when stacking can happen (flags)
        if (currentLane._styleFlags & (TLVLaneTimePoint|TLVLaneLaneLabel) && currentLane._naturalHeight === undefined)
            [self dataForLane:currentLane];  // calculate height and cache in _naturalHeight;

        if (currentLane._naturalHeight)
        {   totalHeight -= currentLane._naturalHeight;
            fixedCount++;
        }

    }

    var laneHeight = (totalHeight - _rulerRect.size.height) / (laneCount - fixedCount);

    for (var i = 0; i < laneCount; i++)
    {
        var currentLane = [_timeLanes objectAtIndex:i];
        [currentLane setFrameOrigin:currentOrigin];
        var effectiveHeight = currentLane._naturalHeight? currentLane._naturalHeight : laneHeight;
        [currentLane setFrameSize:CPMakeSize(self._frame.size.width, effectiveHeight)];
        currentOrigin.y += effectiveHeight;
    }
}
// the array has to contain KVC-compliant objects that have CPDates stored in the key specified by timeKey
- (void)setObjectValue:(CPArray)someValue
{
    [super setObjectValue:someValue];
    _range = [self getDateRange];
    [self tile];
    [self setNeedsDisplay:YES];
    [_timeLanes makeObjectsPerformSelector:@selector(setNeedsDisplay:) withObject:YES];
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
