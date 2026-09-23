import 'package:flutter/material.dart';

import '../data/my_note_data.dart';

String noteTemplateLabel(NoteTemplateType type) {
  return switch (type) {
    NoteTemplateType.general => '筆記',
    NoteTemplateType.plan => '計劃',
    NoteTemplateType.mindMap => '心智圖',
    NoteTemplateType.lifeSheet => '人生試算表',
  };
}

String noteTemplateDescription(NoteTemplateType type) {
  return switch (type) {
    NoteTemplateType.general => '自由文字、圖片、附件與背景設定',
    NoteTemplateType.plan => '目標、階段、任務、進度、日期與備註',
    NoteTemplateType.mindMap => '主題、節點、座標、顏色與展開狀態',
    NoteTemplateType.lifeSheet => '計劃連結、金額目標、目前金額與圖表資料',
  };
}

String noteBodyLabel(NoteTemplateType type) {
  return switch (type) {
    NoteTemplateType.general => '內文',
    NoteTemplateType.plan => '計劃補充內容',
    NoteTemplateType.mindMap => '心智圖補充內容',
    NoteTemplateType.lifeSheet => '試算表補充內容',
  };
}

IconData noteTemplateIcon(NoteTemplateType type) {
  return switch (type) {
    NoteTemplateType.general => Icons.notes,
    NoteTemplateType.plan => Icons.flag_outlined,
    NoteTemplateType.mindMap => Icons.account_tree_outlined,
    NoteTemplateType.lifeSheet => Icons.stacked_bar_chart,
  };
}
