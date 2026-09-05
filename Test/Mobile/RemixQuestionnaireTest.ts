import { App, Content, Label, Node, Path, sleep, thread } from "Dora";
import { startMobileRemix, type MobileRemixServices } from "Dev/Mobile/Remix";
import { buildQuestionnaireAnswers } from "Dev/Mobile/RemixModel";

thread(() => {
	const marker = Path(Content.appPath, "mobile-remix-questionnaire-test.result");
	let host: Node.Type | undefined;
	Content.save(marker, "running");
	try {
		const session = { id: 1, status: "WAITING_USER", workMode: "plan" } as never;
		const questions = [{
			id: "layout",
			prompt: "First line of the question\nSecond line of the question\nThird line of the question",
			type: "single_choice",
			required: false,
			options: [{ id: "first", label: "First option" }],
		}] as never;
		const detail = {
			success: true,
			session,
			messages: [],
			steps: [],
			hasActivePlan: false,
			pendingQuestionnaire: {
				id: 1,
				schema: {
					title: "Layout test",
					questions,
				},
			},
		} as never;
		const services: MobileRemixServices = {
			createSession: () => ({ success: true, session }),
			getSession: () => detail,
			setWorkMode: () => ({ success: true }),
			sendPrompt: () => ({ success: true } as never),
			respondQuestionnaire: () => ({ success: true } as never),
			stopSessionTask: () => undefined,
			getActiveLLMConfig: () => ({ success: false, message: "not needed" }),
			getLLMConfig: () => ({ success: false, message: "not needed" }),
			getLLMConfigSummaries: () => [{ id: 1, name: "Test" }] as never,
		};
		host = startMobileRemix({
			entry: { id: "layout", title: "Layout test", workDir: Content.writablePath },
			onBack: () => {},
			onPlay: () => {},
			services,
		});
		sleep();
		let prompt: Label.Type | undefined;
		let option: Node.Type | undefined;
		host.traverse(node => {
			if (node.tag === "remix-question-prompt") prompt = node as Label.Type;
			if (node.tag === "remix-question-layout-option-first") option = node;
			return false;
		});
		assert(prompt && option, "questionnaire nodes were not rendered");
		const promptNode = prompt!;
		const optionNode = option!;
		const gap = promptNode.y - promptNode.height / 2 - (optionNode.y + optionNode.height);
		assert(gap >= 13.5, `multi-line prompt gap is too small: ${gap}`);
		let skip: Node.Type | undefined;
		host.traverse(node => { if (node.tag === "remix-question-skip") skip = node; return false; });
		assert(skip, "optional question did not render a skip action");
		const answers = buildQuestionnaireAnswers(questions, {}, {});
		assert(answers[0].questionId === "layout" && answers[0].status === "skipped", "empty optional answer was not serialized as skipped");
		Content.save(marker, `passed: multi-line prompt gap ${gap}; optional question skipped`);
	} catch (e) { Content.save(marker, `failed: ${tostring(e)}`); }
	finally { host?.removeFromParent(true); }
});
