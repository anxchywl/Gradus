library;

import 'package:flutter/widgets.dart';

import 'src/application/gpa_controller.dart';
import 'src/config/gpa_scope.dart';
import 'src/config/gpa_session.dart';
import 'src/l10n/gpa_strings.dart';
import 'src/presentation/gpa_screen.dart';

export 'src/config/gpa_scope.dart'
    show
        GpaDependencies,
        GpaScope,
        createLocalDependencies,
        createSampleDependencies;
export 'src/config/gpa_session.dart' show GpaBackend, GpaConfig, GpaSession;
export 'src/domain/assignment.dart' show Assignment;
export 'src/domain/course.dart' show Course, GradingMode;
export 'src/domain/course_grade.dart'
    show CourseGrade, GradeSource, calculateCourseGrade;
export 'src/domain/errors.dart';
export 'src/domain/gpa.dart' show GpaResult, calculateGpa;
export 'src/domain/grade.dart'
    show FourPointScale, Grade, GradeBand, GradeScale;
export 'src/domain/semester.dart' show Semester;
export 'src/domain/transcript.dart' show Transcript;
export 'src/l10n/gpa_strings.dart' show GpaStrings, supportedGpaLocales;

class GpaFeature extends StatefulWidget {
  const GpaFeature({
    super.key,
    required this.session,
    required this.dependencies,
    required this.config,
  });

  final GpaSession session;
  final GpaDependencies dependencies;
  final GpaConfig config;

  @override
  State<GpaFeature> createState() => _GpaFeatureState();
}

class _GpaFeatureState extends State<GpaFeature> {
  late GpaController _controller = widget.dependencies.createController();

  @override
  void didUpdateWidget(GpaFeature oldWidget) {
    super.didUpdateWidget(oldWidget);
    // only a new session retires the controller, a rebuild keeps what is loaded
    if (oldWidget.session.accessToken == widget.session.accessToken &&
        oldWidget.session.accountId == widget.session.accountId) {
      return;
    }
    _controller.dispose();
    _controller = widget.dependencies.createController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // the host may not register our delegate, so the feature scopes its own
    return GpaStringsScope(
      child: GpaScope(
        // a new token remounts the subtree, discarding the previous account
        key: ValueKey(widget.session.accessToken),
        session: widget.session,
        gpa: _controller,
        child: const GpaScreen(),
      ),
    );
  }
}
