import 'dart:js_interop';
import 'dart:ui';
import 'package:web/web.dart' as web;

// lib/helper/web_helper.dart
// Web-specific CanvasRenderingContext2D helpers.
// These functions directly map to HTML Canvas 2D context operations.

/// Set the fill style using an 'r,g,b,a' string (converted to 'rgba(...)').
void fillStyle(dynamic context2D, String fillColor) {
  if (context2D is web.CanvasRenderingContext2D) {
    context2D.fillStyle = 'rgba($fillColor)'.toJS;
  }
}

/// Set the stroke style using an 'r,g,b,a' string (converted to 'rgba(...)').
void strokeStyle(dynamic context2D, String strokeColor) {
  if (context2D is web.CanvasRenderingContext2D) {
    context2D.strokeStyle = 'rgba($strokeColor)'.toJS;
  }
}

/// Fill a rectangle from (0,0) to size.width x size.height.
void fillRect(dynamic context2D, Size size) {
  if (context2D is web.CanvasRenderingContext2D) {
    context2D.fillRect(0, 0, size.width, size.height);
  }
}

/// Fill the current path.
void fill(dynamic context2D) {
  if (context2D is web.CanvasRenderingContext2D) {
    context2D.fill();
  }
}

/// Set the line cap style: 'butt', 'round', or 'square'.
void lineCap(dynamic context2D, String lineCap) {
  if (context2D is web.CanvasRenderingContext2D) {
    context2D.lineCap = lineCap;
  }
}

/// Set the current stroke width in pixels.
void lineWidth(dynamic context2D, double lineWidth) {
  if (context2D is web.CanvasRenderingContext2D) {
    context2D.lineWidth = lineWidth;
  }
}

/// Stroke the current path.
void stroke(dynamic context2D) {
  if (context2D is web.CanvasRenderingContext2D) {
    context2D.stroke();
  }
}

/// Begin a new path.
void beginPath(dynamic context2D) {
  if (context2D is web.CanvasRenderingContext2D) {
    context2D.beginPath();
  }
}

/// Add an arc (circle segment) to the current path and move to its start.
void drawContext2DArc(
  dynamic context2D,
  double x,
  double y,
  double radius,
  double startAngle,
  double endAngle,
  bool counterclockwise,
) {
  if (context2D is web.CanvasRenderingContext2D) {
    context2D.moveTo(x, y);
    context2D.arc(x, y, radius, startAngle, endAngle, counterclockwise);
  }
}

/// Add a straight line segment to the current path.
void drawContext2DLine(
  dynamic context2D,
  double x,
  double y,
  double x1,
  double y1,
) {
  if (context2D is web.CanvasRenderingContext2D) {
    context2D.moveTo(x, y);
    context2D.lineTo(x1, y1);
  }
}
