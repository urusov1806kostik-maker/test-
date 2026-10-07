package dev.shadowvisuals.setting;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** Collapsible group of settings. Children are added through {@link SettingRegistry#add(SettingGroup, SettingNode)}. */
public final class SettingGroup extends SettingNode {
	private final List<SettingNode> children = new ArrayList<>();
	private final List<SettingNode> view = Collections.unmodifiableList(children);
	private final boolean expandedByDefault;

	public SettingGroup(String id) {
		this(id, true);
	}

	public SettingGroup(String id, boolean expandedByDefault) {
		super(id);
		this.expandedByDefault = expandedByDefault;
	}

	public boolean expandedByDefault() {
		return expandedByDefault;
	}

	public List<SettingNode> children() {
		return view;
	}

	void addChild(SettingNode node) {
		children.add(node);
	}

	@Override
	public void reset() {
		for (SettingNode child : children) {
			child.reset();
		}
	}
}
