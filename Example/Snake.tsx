// @preview-file on clear
import { React, toNode } from 'DoraX';
import { Node, Size, Vec2, Director, Label, Sequence, Spawn, Ease, Color, threadLoop, KeyName, TextAlign, DrawNode, Scale, App, tolua, TypeName, View, Line, ButtonName } from "Dora";
import { CreateManager, Trigger, GamePad } from 'InputManager';

const KeyDown = (keyName: KeyName, buttonName: ButtonName) => {
	return Trigger.Selector([
		Trigger.KeyDown(keyName),
		Trigger.ButtonDown(buttonName)
	]);
};

const inputManager = CreateManager({
	Game: {
		Up: KeyDown(KeyName.W, ButtonName.Up),
		Down: KeyDown(KeyName.S, ButtonName.Down),
		Left: KeyDown(KeyName.A, ButtonName.Left),
		Right: KeyDown(KeyName.D, ButtonName.Right),
		Start: KeyDown(KeyName.R, ButtonName.B)
	},
});

inputManager.getNode().addTo(Director.ui);

toNode(
	<GamePad inputManager={inputManager} noLeftStick noRightStick noTriggerPad noControlPad/>
)?.addTo(Director.ui);

inputManager.pushContext('Game');

// 游戏常量
const GRID_SIZE = 20;
const CELL_SIZE = 20;
const GAME_WIDTH = GRID_SIZE * CELL_SIZE;
const GAME_HEIGHT = GRID_SIZE * CELL_SIZE;
const INITIAL_SPEED = 0.15;

// 自适应游戏窗口
const updateViewSize = () => {
	const camera = tolua.cast(Director.currentCamera, TypeName.Camera2D);
	if (camera) {
		camera.zoom = View.size.height / GAME_HEIGHT;
	}
};
updateViewSize();
Director.entry.onAppChange(settingName => {
	if (settingName === 'Size') {
		updateViewSize();
	}
});

// 方向枚举
const enum Direction {
	Up = "Up",
	Down = "Down",
	Left = "Left",
	Right = "Right"
}

function filterChild(node: Node.Type, filter: (node: Node.Type) => boolean) {
	let children: Node.Type[] = [];
	node.eachChild((child) => {
		if (filter(child)) {
			children.push(child);
		}
		return false;
	});
	return children;
}

class SnakeGame {
	private root: Node.Type;
	private snake: Vec2.Type[] = [];
	private food: Vec2.Type | null = null;
	private currentDirection = Direction.Right;
	private nextDirection = Direction.Right;
	private score = 0;
	private scoreLabel: Label.Type;
	private gameOverLabel: Label.Type;
	private isGameOver = false;
	private speed = INITIAL_SPEED;
	private lastMoveTime = 0;

	constructor() {
		Line([
			Vec2(-GAME_WIDTH / 2, -GAME_HEIGHT / 2),
			Vec2(GAME_WIDTH / 2, -GAME_HEIGHT / 2),
			Vec2(GAME_WIDTH / 2, GAME_HEIGHT / 2 - 1),
			Vec2(-GAME_WIDTH / 2, GAME_HEIGHT / 2 - 1),
			Vec2(-GAME_WIDTH / 2, -GAME_HEIGHT / 2),
		]).addTo(Director.entry);

		// 创建游戏根节点
		this.root = Node();
		this.root.size = Size(GAME_WIDTH, GAME_HEIGHT);
		Director.entry.addChild(this.root);

		// 创建分数标签
		this.scoreLabel = Label("sarasa-mono-sc-regular", 30 * 2, true)!;
		this.scoreLabel.scaleX = 0.5;
		this.scoreLabel.scaleY = 0.5;
		this.scoreLabel.text = "Score: 0";
		this.scoreLabel.position = Vec2(80, GAME_HEIGHT - 30);
		this.scoreLabel.alignment = TextAlign.Left;
		this.root.addChild(this.scoreLabel, 1);

		// 创建游戏结束标签（初始隐藏）
		this.gameOverLabel = Label("sarasa-mono-sc-regular", 36 * 2, true)!;
		this.gameOverLabel.scaleX = 0.5;
		this.gameOverLabel.scaleY = 0.5;
		this.gameOverLabel.text = "Game Over!\nPress R to restart";
		this.gameOverLabel.position = Vec2(GAME_WIDTH / 2, GAME_HEIGHT / 2);
		this.gameOverLabel.visible = false;
		this.root.addChild(this.gameOverLabel, 1);

		// 初始化游戏
		this.resetGame();

		// 设置键盘控制
		this.setupControls();

		// 开始游戏循环
		this.startGameLoop();
	}

	private resetGame() {
		// 清除现有的蛇身
		filterChild(this.root, child => child.tag === "snake" || child.tag === "food")
			.forEach(child => {
				child.removeFromParent();
			});

		// 重置游戏状态
		this.snake = [
			Vec2(5, 10),
			Vec2(4, 10),
			Vec2(3, 10)
		];
		this.currentDirection = Direction.Right;
		this.nextDirection = Direction.Right;
		this.score = 0;
		this.speed = INITIAL_SPEED;
		this.isGameOver = false;
		this.lastMoveTime = 0;
		this.scoreLabel.text = `Score: ${this.score}`;
		this.gameOverLabel.visible = false;

		// 绘制初始蛇身
		this.drawSnake();

		// 生成食物
		this.spawnFood();
	}

	private drawSnake() {
		// 移除旧的蛇身节点
		filterChild(this.root, child => child.tag === "snake")
			.forEach(child => {
				child.removeFromParent();
			});

		// 绘制新的蛇身
		for (const segment of this.snake) {
			const segmentNode = Node();
			segmentNode.tag = "snake";
			segmentNode.size = Size(CELL_SIZE, CELL_SIZE);
			segmentNode.position = Vec2(
				segment.x * CELL_SIZE + CELL_SIZE / 2,
				segment.y * CELL_SIZE + CELL_SIZE / 2
			);

			const drawNode = DrawNode();
			drawNode.position = Vec2(CELL_SIZE / 2, CELL_SIZE / 2);
			segmentNode.addChild(drawNode);

			drawNode.drawPolygon(
				[
					Vec2(-CELL_SIZE/2, -CELL_SIZE/2),
					Vec2(CELL_SIZE/2, -CELL_SIZE/2),
					Vec2(CELL_SIZE/2, CELL_SIZE/2),
					Vec2(-CELL_SIZE/2, CELL_SIZE/2)
				],
				Color(0, 255, 0, 255),
				1,
				Color(0, 200, 0, 255)
			);
			
			this.root.addChild(segmentNode);
		}
	}

	private spawnFood() {
		// 移除旧的食物
		filterChild(this.root, child => child.tag === "food")
			.forEach(child => {
				child.removeFromParent();
			});

		// 生成新的食物位置
		const availableCells: Vec2.Type[] = [];
		for (let x = 0; x < GRID_SIZE; x++) {
			for (let y = 0; y < GRID_SIZE; y++) {
				const pos = Vec2(x, y);
				if (!this.snake.some(segment => segment.equals(pos))) {
					availableCells.push(pos);
				}
			}
		}

		if (availableCells.length === 0) {
			// 蛇已经填满整个屏幕，游戏胜利
			this.gameOver(true);
			return;
		}

		const randomIndex = Math.floor(Math.random() * availableCells.length);
		this.food = availableCells[randomIndex];

		// 绘制食物
		const foodNode = Node();
		foodNode.tag = "food";
		foodNode.size = Size(CELL_SIZE, CELL_SIZE);
		foodNode.position = Vec2(
			this.food.x * CELL_SIZE + CELL_SIZE / 2,
			this.food.y * CELL_SIZE + CELL_SIZE / 2
		);

		const drawNode = DrawNode();
		drawNode.position = Vec2(CELL_SIZE / 2, CELL_SIZE / 2);
		foodNode.addChild(drawNode);

		drawNode.drawPolygon(
			[
				Vec2(-CELL_SIZE/2, -CELL_SIZE/2),
				Vec2(CELL_SIZE/2, -CELL_SIZE/2),
				Vec2(CELL_SIZE/2, CELL_SIZE/2),
				Vec2(-CELL_SIZE/2, CELL_SIZE/2)
			],
			Color(255, 0, 0, 255),
			1,
			Color(200, 0, 0, 255)
		);

		// 添加动画效果
		foodNode.runAction(Sequence(
			Spawn(
				Scale(0.5, 1.0, 0.8, Ease.OutBack),
				Scale(0.5, 1.0, 1.2, Ease.OutBack)
			),
			Spawn(
				Scale(0.5, 0.8, 1.0, Ease.OutBack),
				Scale(0.5, 1.2, 1.0, Ease.OutBack)
			)
		));

		this.root.addChild(foodNode);
	}

	private moveSnake() {
		if (this.isGameOver) return;

		const head = this.snake[0];
		let newHead: Vec2.Type;

		// 根据当前方向计算新头部位置
		switch (this.currentDirection) {
			case Direction.Up:
				newHead = Vec2(head.x, head.y + 1);
				break;
			case Direction.Down:
				newHead = Vec2(head.x, head.y - 1);
				break;
			case Direction.Left:
				newHead = Vec2(head.x - 1, head.y);
				break;
			case Direction.Right:
				newHead = Vec2(head.x + 1, head.y);
				break;
		}

		// 检查碰撞
		if (
			newHead.x < 0 || newHead.x >= GRID_SIZE ||
			newHead.y < 0 || newHead.y >= GRID_SIZE ||
			this.snake.some(segment => segment.equals(newHead), 1) // 跳过头部检查
		) {
			this.gameOver();
			return;
		}

		// 移动蛇
		this.snake.unshift(newHead);

		// 检查是否吃到食物
		if (this.food && newHead.equals(this.food)) {
			this.score++;
			this.scoreLabel.text = `Score: ${this.score}`;

			// 每得5分加快速度
			if (this.score % 5 === 0) {
				this.speed = Math.max(0.05, this.speed * 0.9);
			}

			this.spawnFood();
		} else {
			// 如果没有吃到食物，移除尾部
			this.snake.pop();
		}

		// 绘制蛇
		this.drawSnake();

		// 更新方向
		this.currentDirection = this.nextDirection;
	}

	private gameOver(isWin = false) {
		this.isGameOver = true;
		this.gameOverLabel.text = isWin ? 
			"You Win!\nPress R (B) to restart" : 
			"Game Over!\nPress R (B) to restart";
		this.gameOverLabel.visible = true;
	}

	private setupControls() {
		this.root.gslot("Input.Up", () => {
			if (this.currentDirection !== Direction.Down) {
				this.nextDirection = Direction.Up;
			}
		});
		this.root.gslot("Input.Down", () => {
			if (this.currentDirection !== Direction.Up) {
				this.nextDirection = Direction.Down;
			}
		});
		this.root.gslot("Input.Left", () => {
			if (this.currentDirection !== Direction.Right) {
				this.nextDirection = Direction.Left;
			}
		});
		this.root.gslot("Input.Right", () => {
			if (this.currentDirection !== Direction.Left) {
				this.nextDirection = Direction.Right;
			}
		});
		this.root.gslot("Input.Start", () => {
			if (this.isGameOver) {
				this.resetGame();
			}
		});
	}

	private startGameLoop() {
		threadLoop(() => {
			const now = App.runningTime;
			if (now - this.lastMoveTime >= this.speed) {
				this.moveSnake();
				this.lastMoveTime = now;
			}
			return false;
		});
	}
}

// 启动游戏
new SnakeGame();
