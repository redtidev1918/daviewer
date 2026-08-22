import 'package:daviewer/core/data/html_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('htmlToPlainText strips tags and keeps block breaks', () {
    expect(
      htmlToPlainText('<p>Hello<br>World</p><p>Next</p>'),
      'Hello\nWorld\nNext',
    );
  });

  test('htmlToPlainText decodes common entities', () {
    expect(htmlToPlainText('A&amp;B &lt;tag&gt;'), 'A&B <tag>');
  });

  test('tiptapToPlainText unwraps document and hardBreaks', () {
    const doc = '{"version":1,"document":{"type":"doc","content":['
        '{"type":"paragraph","content":['
        '{"type":"text","text":"Hi"},{"type":"hardBreak"},'
        '{"type":"text","text":"There"}]}]}}';
    expect(tiptapToPlainText(doc), 'Hi\nThere');
  });

  test('tiptapToHtml preserves inline marks', () {
    const doc = '{"document":{"type":"doc","content":['
        '{"type":"paragraph","content":['
        '{"type":"text","text":"Bold","marks":[{"type":"bold"}]}]}]}}';
    expect(tiptapToHtml(doc), contains('<b>Bold</b>'));
  });

  test('tiptapToHtml renders a link mark', () {
    const doc = '{"document":{"type":"doc","content":['
        '{"type":"paragraph","content":['
        '{"type":"text","text":"go","marks":['
        '{"type":"link","attrs":{"href":"https://e.test"}}]}]}]}}';
    expect(tiptapToHtml(doc), contains('<a href="https://e.test">go</a>'));
  });

  test('tiptapToHtml renders an embedded image with a resolved URL', () {
    const doc = '{"version":1,"document":{"type":"doc","content":['
        '{"type":"da-deviation","attrs":{"deviation":{"media":'
        '{"baseUri":"https://x.test/a.jpg","prettyName":"p","token":["t"],'
        '"types":[{"t":"fullview","r":0,"c":"v1/fill/w_1280","w":1280}]'
        '}}}}]}}';
    final html = tiptapToHtml(doc);
    expect(
      html,
      contains('<img src="https://x.test/a.jpg/v1/fill/w_1280?token=t"'),
    );
  });

  test('tiptapToHtml returns empty for invalid JSON', () {
    expect(tiptapToHtml('not-json'), isEmpty);
  });
}
