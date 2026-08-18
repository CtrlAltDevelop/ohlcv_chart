import '../entity/k_line_entity.dart';

class InfoWindowEntity {
  InfoWindowEntity(
    this.kLineEntity, {
    this.kLinePreviousEntity,
    this.isLeft = false,
  });

  KLineEntity? kLinePreviousEntity;
  KLineEntity kLineEntity;
  bool isLeft;
}
