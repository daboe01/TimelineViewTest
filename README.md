# TimelineView
* This is a multipurpose timeline view for cappuccino.
* The view maintains a responsive horizontal master time axis ruler.
* This ruler supports a left and a right clip marker that can be set programmatically and with the mouse.
* These markers can be used to clip and scale the contents through an action method.
* TimelineView manages one or several lanes that are stacked horizontally. A lane represent either numeric or categorial data.
* The data are provided in an array with CPDictionaries. The data are associated to the lanes by a key that has to be provided during setup. The time information has to be provided either  in CPDate objects or in  iso format date strings.
* Numerical data are supported by a responsive y-axis ruler.
* Categorial data comprise either time ranges or points in time.
