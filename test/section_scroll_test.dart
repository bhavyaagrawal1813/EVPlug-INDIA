import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors the offset maths used by HomeContentScreen.scrollToSection,
/// so the behaviour is verified against a real scrollable.
void main() {
  testWidgets('section jump lands the section just below the top edge', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final scrollViewKey = GlobalKey();
    final communityKey = GlobalKey();

    addTearDown(scrollController.dispose);

    late BuildContext communityContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            key: scrollViewKey,
            controller: scrollController,
            child: Column(
              children: [
                const SizedBox(height: 2500, child: ColoredBox(color: Colors.red)),
                Builder(
                  builder: (context) {
                    communityContext = context;
                    return Container(
                      key: communityKey,
                      height: 400,
                      color: Colors.blue,
                    );
                  },
                ),
                // Trailing content so the section can actually reach the
                // top of the viewport without clamping.
                const SizedBox(height: 900, child: ColoredBox(color: Colors.green)),
              ],
            ),
          ),
        ),
      ),
    );

    expect(scrollController.offset, 0);

    final viewport = scrollViewKey.currentContext!.findRenderObject()!;
    final box =
        communityContext.findRenderObject() as RenderBox;

    final delta = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final target = (scrollController.position.pixels + delta - 12).clamp(
      scrollController.position.minScrollExtent,
      scrollController.position.maxScrollExtent,
    );

    scrollController.jumpTo(target);
    await tester.pumpAndSettle();

    // The section header should now sit ~12px from the top of the
    // viewport, not flush and not far below it.
    final landed = box.localToGlobal(Offset.zero, ancestor: viewport).dy;

    expect(landed, moreOrLessEquals(12, epsilon: 1.0));
    expect(scrollController.offset, greaterThan(2000));
  });

  testWidgets('jumping near the end clamps to maxScrollExtent', (
    tester,
  ) async {
    final scrollController = ScrollController();
    final scrollViewKey = GlobalKey();
    final communityKey = GlobalKey();

    addTearDown(scrollController.dispose);

    late BuildContext communityContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            key: scrollViewKey,
            controller: scrollController,
            child: Column(
              children: [
                const SizedBox(height: 900, child: ColoredBox(color: Colors.red)),
                Builder(
                  builder: (context) {
                    communityContext = context;
                    return Container(key: communityKey, color: Colors.blue);
                  },
                ),
                const SizedBox(height: 100, child: ColoredBox(color: Colors.green)),
              ],
            ),
          ),
        ),
      ),
    );

    final viewport = scrollViewKey.currentContext!.findRenderObject()!;
    final box = communityContext.findRenderObject() as RenderBox;

    final delta = box.localToGlobal(Offset.zero, ancestor: viewport).dy;
    final target = (scrollController.position.pixels + delta - 12).clamp(
      scrollController.position.minScrollExtent,
      scrollController.position.maxScrollExtent,
    );

    scrollController.jumpTo(target);
    await tester.pumpAndSettle();

    expect(
      scrollController.offset,
      scrollController.position.maxScrollExtent,
    );
  });
}
