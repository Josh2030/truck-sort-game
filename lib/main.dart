import 'splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flame/effects.dart';

void main() {
  runApp(const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    if (!_splashDone) {
      return MaterialApp(
        home: SplashScreen(
          onComplete: () {
            setState(() {
              _splashDone = true;
            });
          },
        ),
      );
    }

    return GameWidget(game: TruckSortGame());
  }
}

typedef ShapeDef = List<List<int>>;

class ItemShapes {
  static const ShapeDef box1x1 = [[0, 0]];
  static const ShapeDef couch1x3 = [[0, 0], [0, 1], [0, 2]];
  static const ShapeDef crate2x2 = [[0, 0], [0, 1], [1, 0], [1, 1]];
  static const ShapeDef tiresL = [[0, 0], [0, 1], [1, 0]];

  static const List<ShapeDef> sequence = [
    box1x1,
    couch1x3,
    crate2x2,
    box1x1,
    tiresL,
    box1x1,
    couch1x3,
    crate2x2,
  ];
}

class TruckSortGame extends FlameGame {
  static const int columns = 5;
  static const int rows = 4;
  static const double cellSize = 60;

  late double offsetX;
  late double offsetY;
  int sequenceIndex = 0;
  bool roundOver = false;

  List<List<bool>> filled = List.generate(
    rows,
    (_) => List.generate(columns, (_) => false),
  );

  late TruckBed truckBed;

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final gridWidth = columns * cellSize;
    final gridHeight = rows * cellSize;

    offsetX = (size.x - gridWidth) / 2;
    offsetY = size.y * 0.15;

    final truckSprite = await loadSprite('Red_truck.png');
    final truckImage = SpriteComponent(
      sprite: truckSprite,
      size: Vector2(gridHeight + 280, gridWidth + 60),
      anchor: Anchor.center,
      position: Vector2(offsetX + gridWidth / 2, offsetY + gridHeight / 2),
      angle: 1.5708,
      priority: 0,
    );
    add(truckImage);

    truckBed = TruckBed(position: Vector2(offsetX, offsetY));
    truckBed.priority = 1;
    // add(truckBed); // temporarily disabled to see truck art clearly




    spawnNewItem();
    add(RestartButton(position: Vector2(20, 20)));
  }

  void restartLevel() {
    children.whereType<DraggableItem>().forEach((item) => item.removeFromParent());
    filled = List.generate(rows, (_) => List.generate(columns, (_) => false));
    sequenceIndex = 0;
    roundOver = false;
    truckBed.position = Vector2(offsetX, offsetY); // reset in case mid-slide
    spawnNewItem();
  }

  void spawnNewItem() {
    if (roundOver) return;

    final shape = ItemShapes.sequence[sequenceIndex % ItemShapes.sequence.length];
    sequenceIndex++;

    final itemStartPosition = Vector2(
      offsetX,
      size.y - cellSize * 3 - 40,
    );

    add(DraggableItem(shape: shape, startPosition: itemStartPosition));
  }

  Vector2? trySnapToGrid(ShapeDef shape, Vector2 dropPosition) {
    final centerX = dropPosition.x + cellSize / 2;
    final centerY = dropPosition.y + cellSize / 2;

    final anchorCol = ((centerX - offsetX) / cellSize).floor();
    final anchorRow = ((centerY - offsetY) / cellSize).floor();

    for (final cell in shape) {
      final r = anchorRow + cell[0];
      final c = anchorCol + cell[1];
      if (r < 0 || r >= rows || c < 0 || c >= columns) return null;
      if (filled[r][c]) return null;
    }

    for (final cell in shape) {
      filled[anchorRow + cell[0]][anchorCol + cell[1]] = true;
    }

    spawnNewItem();
    checkWinCondition();
    return Vector2(offsetX + anchorCol * cellSize, offsetY + anchorRow * cellSize);
  }

  void checkWinCondition() {
    if (roundOver) return;
    final isFull = filled.every((row) => row.every((cell) => cell));
    if (isFull) {
      triggerTruckLeaving();
    }
  }

  void triggerTruckLeaving() {
    roundOver = true;

    final message = TextComponent(
      text: 'Truck Leaving!',
      position: Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          backgroundColor: Color(0xAA000000),
        ),
      ),
    );
    add(message);

    // Lock any remaining draggable items in place visually (they ride away with the truck)
    final itemsStillOnGrid = children.whereType<DraggableItem>().where((i) => i.isPlaced);

    Future.delayed(const Duration(milliseconds: 900), () {
      message.removeFromParent();

      // Slide the truck bed and all placed items off to the right
      truckBed.add(
        MoveEffect.by(
          Vector2(size.x + 200, 0),
          EffectController(duration: 0.6, curve: Curves.easeIn),
          onComplete: () => startNextRound(),
        ),
      );

      for (final item in itemsStillOnGrid) {
        item.add(
          MoveEffect.by(
            Vector2(size.x + 200, 0),
            EffectController(duration: 0.6, curve: Curves.easeIn),
          ),
        );
      }
    });
  }

  void startNextRound() {
    children.whereType<DraggableItem>().forEach((item) => item.removeFromParent());

    filled = List.generate(rows, (_) => List.generate(columns, (_) => false));
    sequenceIndex = 0;
    roundOver = false;

    // Bring the truck bed back from off-screen left, then slide it into place
    truckBed.position = Vector2(-gridPixelWidth - 200, offsetY);
    truckBed.add(
      MoveEffect.to(
        Vector2(offsetX, offsetY),
        EffectController(duration: 0.6, curve: Curves.easeOut),
      ),
    );

    spawnNewItem();
  }

  double get gridPixelWidth => columns * cellSize;

  @override
  Color backgroundColor() => const Color(0xFF87CEEB);
}

// Groups the grid squares into one component so the whole truck bed can move as a unit
class TruckBed extends PositionComponent {
  TruckBed({required Vector2 position})
      : super(position: position, size: Vector2(TruckSortGame.columns * TruckSortGame.cellSize, TruckSortGame.rows * TruckSortGame.cellSize));

  @override
  Future<void> onLoad() async {
    super.onLoad();
    for (int row = 0; row < TruckSortGame.rows; row++) {
      for (int col = 0; col < TruckSortGame.columns; col++) {
        add(
          RectangleComponent(
            position: Vector2(col * TruckSortGame.cellSize, row * TruckSortGame.cellSize),
            size: Vector2(TruckSortGame.cellSize, TruckSortGame.cellSize),
            paint: Paint()
              ..color = const Color(0xFFD2B48C)
              ..style = PaintingStyle.fill,
          ),
        );
        add(
          RectangleComponent(
            position: Vector2(col * TruckSortGame.cellSize, row * TruckSortGame.cellSize),
            size: Vector2(TruckSortGame.cellSize, TruckSortGame.cellSize),
            paint: Paint()
              ..color = const Color(0xFF4A4A4A)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          ),
        );
      }
    }
  }
}

class DraggableItem extends PositionComponent
    with DragCallbacks, HasGameRef<TruckSortGame> {
  ShapeDef shape;
  final Vector2 startPosition;
  bool isPlaced = false;

  DraggableItem({required this.shape, required this.startPosition})
      : super(
          position: startPosition.clone(),
          size: _calculateSize(shape),
        );

  static Vector2 _calculateSize(ShapeDef shape) {
    final maxRow = shape.map((c) => c[0]).reduce((a, b) => a > b ? a : b);
    final maxCol = shape.map((c) => c[1]).reduce((a, b) => a > b ? a : b);
    return Vector2(
      (maxCol + 1) * TruckSortGame.cellSize,
      (maxRow + 1) * TruckSortGame.cellSize,
    );
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    rebuildVisual();
  }

  void rebuildVisual() {
    children.toList().forEach((c) => c.removeFromParent());

    for (final cell in shape) {
      add(
        RectangleComponent(
          position: Vector2(
            cell[1] * TruckSortGame.cellSize,
            cell[0] * TruckSortGame.cellSize,
          ),
          size: Vector2(TruckSortGame.cellSize, TruckSortGame.cellSize),
          paint: Paint()..color = const Color(0xFF8B4513),
        ),
      );
      add(
        RectangleComponent(
          position: Vector2(
            cell[1] * TruckSortGame.cellSize,
            cell[0] * TruckSortGame.cellSize,
          ),
          size: Vector2(TruckSortGame.cellSize, TruckSortGame.cellSize),
          paint: Paint()
            ..color = const Color(0xFF5A2D0C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        ),
      );
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (isPlaced) return;
    position += event.localDelta;
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (isPlaced) return;

    final snapped = gameRef.trySnapToGrid(shape, position);
    if (snapped != null) {
      position = snapped;
      isPlaced = true;
    } else {
      position = startPosition.clone();
    }
  }
}

class RestartButton extends RectangleComponent
    with TapCallbacks, HasGameRef<TruckSortGame> {
  RestartButton({required Vector2 position})
      : super(
          position: position,
          size: Vector2(120, 50),
          anchor: Anchor.topLeft,
          paint: Paint()..color = const Color(0xFFB22222),
        );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    add(RectangleHitbox());
    add(
      TextComponent(
        text: 'Restart',
        position: Vector2(size.x / 2, size.y / 2),
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }

  @override
  void onTapUp(TapUpEvent event) {
    gameRef.restartLevel();
  }
}