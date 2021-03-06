/*
 * AppController.j
 *
 *  Manual test application for the timelineview 
 *  Copyright (C) 2016 Daniel Boehringer
 */
 
@import "TimelineView.j"

@implementation AppController : CPObject
{
    TimelineView  _tlView;
}

- (CPArray)_compiledTestData
{    var testData=[
                   ['private','2006-01-01', '15'],
                   ['private','2006-01-02', '16'],
                   ['private','2006-01-03', '17'],
                   ['private','2006-01-04', '18'],
                   ['private','2006-01-05', '19'],
                   ['private','2006-01-06', '20'],
                   ['private','2006-01-07', '21'],

                   ['work',   '2006-01-01', '50'],
                   ['work',   '2006-01-02', '49'],
                   ['work',   '2006-01-03', '48'],
                   ['work',   '2006-01-04', '47'],
                   ['work',   '2006-01-05', '46'],
                   ['work',   '2006-01-06', '45'],
                   ['work',   '2006-02-20', '44'],

                   ['other',   '2006-01-01', '2006-01-04', 'Arbeit'],
                   ['other',   '2006-01-02', '2006-01-04', 'Freizeit'],
                   ['other',   '2006-01-07', '2006-02-04', 'Sonstiges'],

                   ['other2',   '2006-01-01', 'Arbeit'],
                   ['other2',   '2006-01-02', 'Freizeit'],
                   ['other2',   '2006-01-07', 'Sonstiges']

                 ];
    var out = [];
    var l = testData.length;

    for(var i = 0; i < l; i++)
    {
        if ( testData[i][2].indexOf('-') > -1 ) // range
            out.push(@{'lane': testData[i][0],
                       'date': [[CPDate alloc] initWithShortString:testData[i][1]],
                       'date2': [[CPDate alloc] initWithShortString:testData[i][2]],
                       'value': testData[i][3]})
       else
            out.push(@{'lane': testData[i][0], // data only
                       'date': [[CPDate alloc] initWithShortString:testData[i][1]],
                       'value':testData[i][2]})
    }
    return out;
}

- (void)applicationDidFinishLaunching:(CPNotification)aNotification
{

    var theWindow = [[CPWindow alloc] initWithContentRect:CGRectMakeZero() styleMask:CPBorderlessBridgeWindowMask],
        contentView = [theWindow contentView];
    
    [contentView setBackgroundColor:[CPColor colorWithWhite:0.95 alpha:1.0]];

    _tlView = [[TLVTimelineView alloc] initWithFrame:CGRectMake(0, 0,500,500)];
    [_tlView setLaneKey:'lane'];
    [_tlView setTimeEndKey:'date2'];
    [_tlView setClipScaleLowerDate:[[CPDate alloc] initWithShortString:'2006-01-03' ] ];
    [_tlView setClipScaleUpperDate:[[CPDate alloc] initWithShortString:'2006-01-07' ] ];

    var myLane=[TLVTimeLane new];
    [myLane addStyleFlags:TLVLanePolygon|TLVLaneCircle];
    [myLane setHasVerticalRuler:YES];
    [_tlView addLane:myLane withIdentifier:'private'];

    var myLane=[TLVTimeLane new];
    [myLane addStyleFlags:TLVLanePolygon];
    [myLane setHasVerticalRuler:YES];
    [_tlView addLane:myLane withIdentifier:'work'];

    var myLane=[TLVTimeLane new];
    [myLane setHasVerticalRuler:YES];
    [myLane setMinimumHeight:120];
    [myLane setLabel:"This is a time range"];
    [myLane addStyleFlags:TLVLaneTimeRange|TLVLaneLaneLabel|TLVLaneValueInline];
    [_tlView addLane:myLane withIdentifier:'other'];

    var myLane=[TLVTimeLane new];
    [myLane setHasVerticalRuler:YES];
    [myLane setLabel:"These are simple dates"];
    [myLane addStyleFlags:TLVLaneTimePoint|TLVLaneValueInline];
    [_tlView addLane:myLane withIdentifier:'other2'];

    [_tlView setObjectValue:[self _compiledTestData]];

    var scrollView = [[CPScrollView alloc] initWithFrame:CGRectMake(20, 20,520,510)];
    [scrollView setDocumentView:_tlView]; 

    [contentView addSubview:scrollView];

    var myslider=[[CPSlider alloc] initWithFrame:CGRectMake(0, 550, 70, 25)];
    [myslider setObjectValue:1.0]
    [myslider setMinValue:0.5]
    [myslider setMaxValue:1.5]
    [myslider setTarget:self]
    [myslider setAction:@selector(doScale:)]
    [contentView addSubview: myslider]


    var mybutton=[[CPButton alloc] initWithFrame:CGRectMake(0, 600, 70, 25)];
    [mybutton setTitle:"Clipscale"]
    [mybutton setTarget:self]
    [mybutton setAction:@selector(doClipscale:)]
    [contentView addSubview:mybutton]

    [theWindow orderFront:self];
}

@end
