/*
 * AppController.j
 *
 *  Manual test application for the timelineview 
 *  Copyright (C) 2016 Daniel Boehringer
 */
 
@import "TimelineView.j"

@implementation CPDate(shortDescription)
- (CPString)shortDescription
{
    return [CPString stringWithFormat:@"%04d-%02d-%02d", self.getFullYear(), self.getMonth() + 1, self.getDate()];
}
- (id)initWithShortString:(CPString)description
{
    var format = /(\d{4})-(\d{2})-(\d{2})/,
        d = description.match(new RegExp(format));
    return new Date(d[1], d[2] - 1, d[3]);
}
@end

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
                   ['work',   '2006-02-20', '44']
                 ];
    var out = [];
    var l = testData.length;

    for(var i = 0; i < l; i++)
    {
        out.push(@{'lane': testData[i][0],
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

    _tlView = [[TimelineView alloc] initWithFrame:CGRectMake(0, 0,500,500)];
    [_tlView setLaneKey:'lane']

    var myLane=[TimeLane new];
    [myLane addStyleFlags:TLVLaneCircle];
    [_tlView addLane:myLane withIdentifier:'private'];

    var myLane=[TimeLane new];
    [myLane addStyleFlags:TLVLaneCircle];
    [_tlView addLane:myLane withIdentifier:'work'];

    [_tlView setObjectValue:[self _compiledTestData]];

    var scrollView = [[CPScrollView alloc] initWithFrame:CGRectMake(20, 20,520,510)];
    [scrollView setDocumentView:_tlView]; 

    [contentView addSubview:scrollView];

    [theWindow orderFront:self];
}
@end
