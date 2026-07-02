import { Content, Director, Log, Node as DNode, Path, Slot, once } from "Dora";
import type * as Dora from "Dora";
import { React, createRoot, reference, signal } from "DoraX";
import { Column, TextInput } from "UIX";

const resultFile = Path(Content.writablePath, "UIXTextInputControlTest.result");
Content.save(resultFile, "running");

function fail(this: void, message: string): never {
	Content.save(resultFile, `failed: ${message}`);
	error(`[UIXTextInputControlTest] ${message}`);
}

function expect(this: void, condition: boolean, message: string) {
	if (!condition) fail(message);
}

const host = DNode();
Director.ui.addChild(host);
const root = createRoot(host);
const value = signal("");
const submitted = signal("");
const disabledValue = signal("locked");
const limitedValue = signal("");
const inputRef = reference<Dora.AlignNode.Type>();
const disabledRef = reference<Dora.AlignNode.Type>();
const limitedRef = reference<Dora.AlignNode.Type>();

root.render(() => (
	<align-node windowRoot style={{ padding: 8 }}>
		<Column style={{ width: 260, gap: 10 }}>
			<TextInput
				key="name-input"
				ref={inputRef}
				value={value.value}
				placeholder="Name"
				prefixIcon="gear"
				onValueChange={(next: string) => value.value = next}
				onSubmit={(next: string) => submitted.value = next}
			/>
			<TextInput
				key="disabled-input"
				ref={disabledRef}
				value={disabledValue.value}
				disabled
				onValueChange={(next: string) => disabledValue.value = next}
			/>
			<TextInput
				key="limited-input"
				ref={limitedRef}
				value={limitedValue.value}
				maxLength={10}
				onValueChange={(next: string) => limitedValue.value = next}
			/>
		</Column>
	</align-node>
));

Director.systemScheduler.schedule(once(() => {
	expect(inputRef.current !== undefined, "input ref missing");
	expect(disabledRef.current !== undefined, "disabled input ref missing");
	expect(limitedRef.current !== undefined, "limited input ref missing");
	inputRef.current!.emit(Slot.Tapped);
	inputRef.current!.emit(Slot.TextInput, "Do");
	Director.systemScheduler.schedule(once(() => {
		expect(value.value === "Do", "text input did not append text");
		inputRef.current!.emit(Slot.TextInput, "ra");
		inputRef.current!.emit(Slot.KeyPressed, "BackSpace");
		Director.systemScheduler.schedule(once(() => {
			expect(value.value === "Dor", "backspace did not remove one UTF-8 character");
			inputRef.current!.emit(Slot.TextInput, "a");
			inputRef.current!.emit(Slot.KeyPressed, "Return");
			Director.systemScheduler.schedule(once(() => {
				expect(value.value === "Dora", "final text value mismatch");
				expect(submitted.value === "Dora", "return did not submit current value");
				disabledRef.current!.emit(Slot.TextInput, "x");
				Director.systemScheduler.schedule(once(() => {
					expect(disabledValue.value === "locked", "disabled input should ignore text");
					limitedValue.value = "123456789";
					Director.systemScheduler.schedule(once(() => {
						limitedRef.current!.emit(Slot.TextEditing, "abcdef");
						Director.systemScheduler.schedule(once(() => {
							expect(limitedValue.value === "123456789a", "IME preview should keep existing text and clamp to max length");
							limitedRef.current!.emit(Slot.TextInput, "abcdef");
							Director.systemScheduler.schedule(once(() => {
								expect(limitedValue.value === "123456789a", "IME commit should append only remaining text at max length");
								Content.save(resultFile, "passed");
								Log("Info", "[UIXTextInputControlTest] passed");
								host.removeFromParent(true);
								root.unmount();
							}));
						}));
					}));
				}));
			}));
		}));
	}));
}));
