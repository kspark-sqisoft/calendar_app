import 'package:flutter/material.dart';

import '../utils/enum.dart';
import '../utils/helper.dart';

/// Render plot band.
///
/// Plot bands are also known as strip lines, which are used to shade the
/// different ranges in plot area with different colors to improve the
/// readability of the chart.
///
/// Plot bands are drawn based on the
/// axis, you have to add plot bands using the plotBands property of the
/// respective axis. You can also add multiple plot bands to an axis.
///
/// Provides the property of visible, opacity, start, end, color, border color,
/// and border width to customize the appearance.
@immutable
class PlotBand {
  /// Creating an argument constructor of PlotBand class.
  const PlotBand({
    this.isVisible = true,
    this.start,
    this.end,
    this.associatedAxisStart,
    this.associatedAxisEnd,
    this.color = Colors.grey,
    this.gradient,
    this.opacity = 1.0,
    this.borderColor = Colors.transparent,
    this.borderWidth = 2,
    this.dashArray = const <double>[0, 0],
    this.text,
    this.textStyle,
    this.textAngle,
    this.verticalTextPadding,
    this.horizontalTextPadding,
    this.verticalTextAlignment = TextAnchor.middle,
    this.horizontalTextAlignment = TextAnchor.middle,
    this.isRepeatable = false,
    this.repeatEvery = 1,
    this.repeatUntil,
    this.size,
    this.sizeType = DateTimeIntervalType.auto,
    this.shouldRenderAboveSeries = false,
  });

  /// Toggles the visibility of the plot band.
  ///
  /// Defaults to `true`.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final bool isVisible;

  /// Specifies the start value of plot band.
  ///
  /// Defaults to `true`.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                     start: 1,
  ///                     end: 5
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final dynamic start;

  /// Specifies the end value of plot band.
  ///
  /// Defaults to `true`.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                     start: 1,
  ///                     end: 5
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final dynamic end;

  /// Text to be displayed in the plot band segment.
  ///
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    text:'Winter'
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final String? text;

  /// Customizes the text style of plot band.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    textStyle: const TextStyle(color:Colors.red)
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final TextStyle? textStyle;

  /// Color of the plot band.
  ///
  /// Defaults to `Colors.grey`.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    color: Colors.red
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final Color color;

  /// Color of the plot band border.
  ///
  /// Defaults to `Colors.transparent`.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    borderColor: Colors.red
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final Color borderColor;

  /// Width of the plot band border.
  ///
  /// Defaults to `0`.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    borderWidth: 2
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final double borderWidth;

  /// Opacity of the plot band. The value ranges from 0 to 1.
  ///
  /// Defaults to `1`.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    opacity: 0.5
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final double opacity;

  /// Specifies the plot band need to be repeated in specified interval.
  ///
  /// Defaults to `false`.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    isRepeatable: true
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final bool isRepeatable;

  /// Interval of the plot band need to be repeated.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    repeatEvery: 200
  ///                )
  ///              ]
  ///           )
  ///        )
  ///     );
  /// }
  /// ```
  final dynamic repeatEvery;

  /// End of the plot band need to be repeated.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    repeatUntil: 600
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final dynamic repeatUntil;

  /// Angle of the plot band text.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    textAngle: 90
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final int? textAngle;

  /// Specifies whether the plot band needs to be rendered above the series.
  ///
  /// Defaults to `false`.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    shouldRenderAboveSeries: true
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final bool shouldRenderAboveSeries;

  /// Date time interval type of the plot band.
  ///
  /// Defaults to  `DateTimeIntervalType.auto`.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    sizeType: DateTimeIntervalType.years
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final DateTimeIntervalType sizeType;

  /// Dashes of the series. Any number of values can be provided in the list.
  /// Odd value is considered as rendering size and even value is considered
  /// as gap.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    dashArray: <double>[10, 10]
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final List<double> dashArray;

  /// Size of the plot band.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    size: 20
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final dynamic size;

  /// Perpendicular axis start value.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    associatedAxisStart: 2
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final dynamic associatedAxisStart;

  /// Perpendicular axis end value.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    associatedAxisEnd: 2
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final dynamic associatedAxisEnd;

  /// Vertical text alignment of the plot band text.
  ///
  /// Defaults to `TextAnchor.middle`.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    verticalTextAlignment: TextAnchor.start
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final TextAnchor verticalTextAlignment;

  /// Horizontal text alignment of the plot band text.
  ///
  /// Defaults to `TextAnchor.middle`.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    horizontalTextAlignment: TextAnchor.end
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final TextAnchor horizontalTextAlignment;

  /// Fills the plot band with gradient color.
  ///
  /// ```dart
  /// final List <Color> color = <Color>[];
  /// final List<double> stops = <double>[];
  ///
  /// Widget build(BuildContext context) {
  ///    color.add(Colors.pink[50]!);
  ///    color.add(Colors.pink[200]!);
  ///    color.add(Colors.pink);
  ///    stops.add(0.0);
  ///    stops.add(0.5);
  ///    stops.add(1.0);
  ///
  ///    final LinearGradient gradients =
  ///        LinearGradient(colors: color, stops: stops);
  ///
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    isVisible:true,
  ///                    gradient: gradients
  ///                )
  ///              ]
  ///           )
  ///        )
  ///     );
  /// }
  /// ```
  final LinearGradient? gradient;

  /// To move the plot band text vertically.
  ///
  /// Takes pixel or percentage value. For pixel, input should be like `10px`
  /// and for percentage input should be like `10%`. If no suffix is specified
  /// (`10`), it will be considered as pixel value. Percentage value refers to
  /// the overall height of the chart. i.e. 100% is equal to the height
  /// of the chart.
  ///
  /// This is applicable for both vertical and horizontal axis. Positive value
  /// for this property moves the text upwards and negative
  /// value moves downwards.
  ///
  /// If [verticalTextAlignment] or [horizontalTextAlignment] is specified,
  /// text padding will be calculated from that modified position.
  ///
  /// Defaults to `null`.
  ///
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    verticalTextPadding:'30%',
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final String? verticalTextPadding;

  /// To move the plot band text horizontally.
  ///
  /// Takes pixel or percentage value. For pixel, input should be like `10px`
  /// and for percentage input should be like `10%`. If no suffix is specified
  /// (`10`), it will be considered as pixel value. Percentage value refers to
  /// the overall width of the chart. i.e. 100% is equal to the width
  /// of the chart.
  ///
  /// This is applicable for both vertical and horizontal axis. Positive value
  /// for this property moves the text to right and negative value
  /// moves to left.
  ///
  /// If [verticalTextAlignment] or [horizontalTextAlignment] is specified,
  /// text padding will be calculated from that modified position.
  ///
  /// Defaults to `null`.
  /// ```dart
  /// Widget build(BuildContext context) {
  ///    return Container(
  ///        child: SfCartesianChart(
  ///           primaryXAxis: NumericAxis(
  ///             plotBands: <PlotBand>[
  ///                PlotBand(
  ///                    horizontalTextPadding:'30%',
  ///                )
  ///              ]
  ///           )
  ///        )
  ///    );
  /// }
  /// ```
  final String? horizontalTextPadding;

  /// The rectangle rendering of a plotband, based on the start
  /// and end values defined.
  ///
  /// Allows complete customization of the plot band custom shapes
  /// appearance using canvas drawing operations.
  ///
  /// Custom visuals such as gradients, patterns, textures, borders, and
  /// transparency effects can be implemented.
  ///
  /// [rect] defines the plot band rendering bounds.
  ///
  /// Example – render a rectangle with corner radius:
  ///
  /// ```dart
  /// class CustomPlotBand extends PlotBand {
  ///   @override
  ///   void drawRect(
  ///     Canvas canvas,
  ///     Rect rect,
  ///     Paint fillPaint, [
  ///     Paint? strokePaint,
  ///   ]) {
  ///     canvas.drawRRect(
  ///       RRect.fromRectAndRadius(rect, const Radius.circular(8)),
  ///       fillPaint,
  ///     );
  ///   }
  /// }
  /// ```
  void drawRect(
    Canvas canvas,
    Rect rect,
    Paint fillPaint, [
    Paint? strokePaint,
  ]) {
    if (fillPaint.color != Colors.transparent && rect.width != 0.0) {
      canvas.drawRect(rect, fillPaint);
    }
    if (strokePaint != null &&
        strokePaint.strokeWidth > 0 &&
        strokePaint.color != Colors.transparent) {
      final double left = rect.left;
      final double top = rect.top;
      final double width = rect.width;
      final double height = rect.height;
      final Path path =
          Path()
            ..moveTo(left, top)
            ..lineTo(left + width, top)
            ..lineTo(left + width, top + height)
            ..lineTo(left, top + height)
            ..close();
      drawDashes(canvas, dashArray, strokePaint, path: path);
    }
  }

  /// Draws the context (label) of a plotband.
  ///
  /// Allows a complete customization of bespoke typography,
  /// dynamic positioning, drop shadows, or interactive effects.
  ///
  /// [position] represents the top-left origin of the text.
  /// [angle] is the clockwise rotation angle in degrees.
  ///
  /// Example – render a rotated label with a pill-shaped highlight:
  ///
  /// ```dart
  /// class RibbonLabelPlotBand extends PlotBand {
  ///   const RibbonLabelPlotBand()
  ///       : super(text: 'Target Range', textAngle: 45);
  ///
  ///   @override
  ///   void drawText(Canvas canvas, Offset position, TextStyle style,
  ///     int angle) {
  ///     final TextPainter painter = TextPainter(
  ///       text: TextSpan(text: text),
  ///       textAlign: TextAlign.center,
  ///       textDirection: TextDirection.ltr,
  ///     )..layout();
  ///     final Offset center =
  ///         position + Offset(painter.width / 2, painter.height / 2);
  ///
  ///     canvas.save();
  ///     canvas.translate(center.dx, center.dy);
  ///     canvas.rotate(angle * (pi / 180));
  ///     final Rect capsule = Rect.fromCenter(
  ///       center: Offset.zero,
  ///       width: painter.width + 12,
  ///       height: painter.height + 8,
  ///     );
  ///     canvas.drawRRect(
  ///       RRect.fromRectAndRadius(capsule, const Radius.circular(12)),
  ///       Paint()..color = Colors.deepPurple.withAlpha(115),
  ///     );
  ///     painter.paint(canvas,
  ///       Offset(-painter.width / 2, -painter.height / 2));
  ///     canvas.restore();
  ///   }
  /// }
  /// ```
  void drawText(Canvas canvas, Offset position, TextStyle style, int angle) {
    if (text == null || text!.isEmpty) {
      return;
    }
    final TextSpan span = TextSpan(text: text, style: style);
    final TextPainter textPainter = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    if (angle == 0) {
      textPainter.paint(canvas, position);
    } else {
      final double halfWidth = textPainter.width / 2;
      final double halfHeight = textPainter.height / 2;
      canvas
        ..save()
        ..translate(position.dx + halfWidth, position.dy + halfHeight)
        ..rotate(degreesToRadians(angle.toDouble()));
      textPainter.paint(canvas, Offset(-halfWidth, -halfHeight));
      canvas.restore();
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    return other is PlotBand &&
        other.isVisible == isVisible &&
        other.start == start &&
        other.end == end &&
        other.color == color &&
        other.opacity == opacity &&
        other.borderColor == borderColor &&
        other.borderWidth == borderWidth &&
        other.text == text &&
        other.textStyle == textStyle &&
        other.isRepeatable == isRepeatable &&
        other.repeatEvery == repeatEvery &&
        other.verticalTextPadding == verticalTextPadding &&
        other.horizontalTextPadding == horizontalTextPadding &&
        other.repeatUntil == repeatUntil &&
        other.textAngle == textAngle &&
        other.shouldRenderAboveSeries == shouldRenderAboveSeries &&
        other.sizeType == sizeType &&
        other.dashArray == dashArray &&
        other.size == size &&
        other.associatedAxisStart == associatedAxisStart &&
        other.associatedAxisEnd == associatedAxisEnd &&
        other.verticalTextAlignment == verticalTextAlignment &&
        other.horizontalTextAlignment == horizontalTextAlignment &&
        other.gradient == gradient;
  }

  @override
  int get hashCode {
    final List<Object?> values = <Object?>[
      isVisible,
      start,
      end,
      color,
      opacity,
      borderColor,
      borderWidth,
      text,
      textStyle,
      isRepeatable,
      repeatEvery,
      verticalTextPadding,
      horizontalTextPadding,
      repeatUntil,
      textAngle,
      shouldRenderAboveSeries,
      sizeType,
      dashArray,
      size,
      associatedAxisStart,
      associatedAxisEnd,
      verticalTextAlignment,
      horizontalTextAlignment,
      gradient,
    ];
    return Object.hashAll(values);
  }
}
