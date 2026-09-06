library;

import 'package:flutter/widgets.dart';

import 'src/application/gradus_controller.dart';
import 'src/config/gradus_scope.dart';
import 'src/config/gradus_session.dart';
import 'src/l10n/gradus_strings.dart';
import 'src/presentation/gradus_screen.dart';

export 'src/config/gradus_scope.dart'
    show
        GradusDependencies,
        GradusScope,
        createLocalDependencies,
        createSampleDependencies,
        createSyllabusImporter;
export 'src/config/gradus_session.dart'
    show GradusBackend, GradusConfig, GradusSession;
export 'src/domain/assignment.dart' show Assignment;
export 'src/domain/course.dart' show Course;
export 'src/domain/course_grade.dart'
    show CourseGrade, GradeSource, calculateCourseGrade;
export 'src/domain/errors.dart';
export 'src/domain/gpa.dart' show GpaResult, calculateGpa;
export 'src/domain/grade.dart'
    show FourPointScale, Grade, GradeBand, GradeScale;
export 'src/domain/repositories.dart' show SyllabusImporter;
export 'src/domain/semester.dart' show Semester;
export 'src/domain/syllabus.dart' show SyllabusAssessment, SyllabusDraft;
export 'src/domain/transcript.dart' show Transcript;
export 'src/l10n/gradus_strings.dart'
    show GradusStrings, supportedGradusLocales;

class GradusFeature extends StatefulWidget {
  const GradusFeature({
    super.key,
    required this.session,
    required this.dependencies,
    required this.config,
  });

  final GradusSession session;
  final GradusDependencies dependencies;
  final GradusConfig config;

  @override
  State<GradusFeature> createState() => _GradusFeatureState();
}

class _GradusFeatureState extends State<GradusFeature> {
  late GradusController _controller = widget.dependencies.createController();

  @override
  void didUpdateWidget(GradusFeature oldWidget) {
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
    return GradusStringsScope(
      child: GradusScope(
        // a new token remounts the subtree, discarding the previous account
        key: ValueKey(widget.session.accessToken),
        session: widget.session,
        controller: _controller,
        child: const GradusScreen(),
      ),
    );
  }
}
