package ui.treeview;
import electron.Dialog;
import electron.FileSystem;
import electron.Menu;
import file.FileKind;
import gml.file.*;
import gml.Project;
import js.RegExp;
import js.html.CSSStyleSheet;
import js.html.DragEvent;
import js.html.Element;
import js.html.DivElement;
import js.html.Event;
import js.html.MouseEvent;
import Main.*;
import js.html.SpanElement;
import js.html.StyleElement;
import tools.Dictionary;
using tools.HtmlTools;
using tools.NativeString;
using tools.PathTools;

/**
 * ...
 * @author YellowAfterlife
 */
class TreeView {
	//
	/** Names of items - used for lookups */
	public static inline var attrIdent:String = "data-ident";
	/** Labels for directories - only used for nesting resolution */
	public static inline var attrLabel:String = "data-label";
	public static inline var attrPath:String = "data-full-path";
	public static inline var attrRel:String = "data-rel-path";
	public static inline var attrKind:String = "data-kind";
	public static inline var attrThumb:String = "data-thumb";
	public static inline var attrThumbDelay:String = "data-thumb-delay";
	public static inline var attrThumbSprite:String = "data-thumb-sprite";
	/** Resource GUID (GMS2 only) */
	public static inline var attrYYID:String = "data-yyid";
	//
	public static inline var clDir:String = "dir";
	public static inline var clItem:String = "item";
	public static inline var clOpen:String = "open";
	//
	public static var element:DivElement;
	public static function clear() {
		element.innerHTML = "";
		//
		var sheet = thumbSheet;
		var rules = sheet.cssRules;
		var i = rules.length;
		while (--i >= 0) sheet.deleteRule(i);
	}
	//
	public static function find(item:Bool, query:TreeViewQuery):Element {
		var qjs = "." + (item ? clItem : clDir);
		if (query.extra != null) qjs += "." + query.extra;
		var check_1:String;
		inline function prop(name:String, value:String) {
			check_1 = value;
			if (check_1 != null) qjs += '[$name="' + check_1.escapeProp() + '"]';
		}
		inline function propPath(name:String, value:String) {
			check_1 = value;
			if (check_1 != null) qjs += '[$name="' + check_1.ptNoBS().escapeProp() + '"]';
		}
		prop(attrIdent, query.ident);
		propPath(attrPath, query.path);
		prop(attrKind, query.kind);
		propPath(attrRel, query.rel);
		return element.querySelector(qjs);
	}
	//
	public static var thumbStyle:StyleElement;
	public static var thumbSheet:CSSStyleSheet;
	public static var thumbMap:Dictionary<String> = new Dictionary();
	public static function hasThumb(itemPath:String):Bool {
		var item = find(true, { path: itemPath });
		return item != null && item.hasAttribute(attrThumb);
	}
	static function addThumbRule(itemPath:String, thumbPath:String) {
		thumbSheet.insertRule('.treeview .item[$attrPath="${itemPath.escapeProp()}"]::before {'
			+ 'background-image: url("${thumbPath.escapeProp()}");'
			+ '}', thumbSheet.cssRules.length);
	}
	public static function setThumb(itemPath:String, thumbPath:String, ?item:Element) {
		if (itemPath == null) {
			if (item != null) {
				itemPath = item.getAttribute(attrPath);
			} else return;
		} else if (item == null) item = find(true, { path: itemPath });
		resetThumb(itemPath, item);
		if (thumbPath == null) return;
		//
		var addRule:Bool;
		if (item != null) {
			item.setAttribute(attrThumb, thumbPath);
			if (item.scrollHeight == 0) {
				item.setAttribute(attrThumbDelay, "");
				addRule = false;
			} else addRule = true;
		} else addRule = true;
		//
		if (addRule) addThumbRule(itemPath, thumbPath);
		thumbMap.set(itemPath, thumbPath);
	}
	public static function setThumbSprite(itemPath:String, spriteName:String, ?item:Element) {
		if (itemPath == null) {
			if (item != null) {
				itemPath = item.getAttribute(attrPath);
			} else return;
		} else if (item == null) item = find(true, { path: itemPath });
		resetThumb(itemPath, item);
		if (spriteName == null) return;
		//
		var addRule:Bool;
		if (item != null) {
			if (item.scrollHeight == 0) {
				item.setAttribute(attrThumbSprite, spriteName);
				item.setAttribute(attrThumbDelay, "");
				addRule = false;
			} else addRule = true;
		} else addRule = true;
		//
		if (addRule) Project.current.getSpriteURLasync(spriteName, function(thumbPath:String) {
			resetThumb(itemPath, item);
			if (thumbPath == null) return;
			addThumbRule(itemPath, thumbPath);
			thumbMap.set(itemPath, thumbPath);
			if (item != null) item.setAttribute(attrThumb, thumbPath);
		});
	}
	public static function resetThumb(itemPath:String, ?item:Element) {
		if (itemPath == null) {
			if (item != null) {
				itemPath = item.getAttribute(attrPath);
			} else return;
		} else if (item == null) item = find(true, { path: itemPath });
		var prefix = '.treeview .item[$attrPath="' + itemPath.escapeProp() + '"]::before {';
		var sheet = thumbSheet;
		var rules = sheet.cssRules;
		var i = rules.length;
		while (--i >= 0) {
			if (rules[i].cssText.indexOf(prefix) >= 0) sheet.deleteRule(i);
		}
		if (item != null) {
			item.removeAttribute(attrThumb);
			item.removeAttribute(attrThumbDelay);
			item.removeAttribute(attrThumbSprite);
		}
		thumbMap.remove(itemPath);
	}
	
	/// Loads the thumbnail for item if it's available but not loaded yet
	static function ensureThumb(item:Element) {
		if (!item.hasAttribute(attrThumbDelay)) return;
		item.removeAttribute(attrThumbDelay);
		if (item.hasAttribute(attrThumbSprite)) {
			var spriteName = item.getAttribute(attrThumbSprite);
			item.removeAttribute(attrThumbSprite);
			Project.current.getSpriteURLasync(spriteName, function(thumbPath:String) {
				if (thumbPath == null) return;
				var itemPath = item.getAttribute(attrPath);
				addThumbRule(itemPath, thumbPath);
				thumbMap.set(itemPath, thumbPath);
				item.setAttribute(attrThumb, thumbPath);
			});
		} else {
			addThumbRule(item.getAttribute(attrPath), item.getAttribute(attrThumb));
		}
		
	}
	
	/// Loads not-yet-loaded thumbnails for all visible item-children of a directory-element.
	static function ensureThumbs(el:Element) {
		for (_e in el.querySelectorAll('.item[$attrThumbDelay]')) {
			var item:TreeViewItem = cast _e;
			if (item.scrollHeight > 0) ensureThumb(item);
		}
	}
	static function handleDirClick(e:MouseEvent) {
		e.preventDefault();
		var el:Element = cast e.target;
		el = el.parentElement;
		if (e.altKey) {
			TreeViewMenus.target = el;
			TreeViewMenus.openCombined();
		} else {
			var cl = el.classList;
			if (!cl.contains(clOpen)) {
				cl.add(clOpen);
				ensureThumbs(el);
			} else cl.remove(clOpen);
		}
	}
	static function handleDirCtxMenu(e:MouseEvent) {
		e.preventDefault();
		var el:Element = cast e.target;
		TreeViewMenus.showDirMenu(el.parentElement, e);
	}
	static function handleItemCtxMenu(e:MouseEvent) {
		e.preventDefault();
		TreeViewMenus.showItemMenu(cast e.target, e);
	}
	//
	public static function makeDir(name:String):TreeViewDir {
		var r:TreeViewDir = cast document.createDivElement();
		r.className = "dir";
		//
		var header = document.createDivElement();
		header.className = "header";
		header.title = name;
		r.treeHeader = header;
		r.appendChild(header);
		//
		var span = document.createSpanElement();
		span.appendChild(document.createTextNode(name));
		header.appendChild(span);
		//
		var c = document.createDivElement();
		c.className = "items";
		r.treeItems = c;
		r.appendChild(c);
		return r;
	}
	public static function makeAssetDir(name:String, rel:String):TreeViewDir {
		rel = rel.ptNoBS();
		var r:TreeViewDir = makeDir(name);
		var header = r.treeHeader;
		header.addEventListener("click", handleDirClick);
		header.addEventListener("contextmenu", handleDirCtxMenu);
		TreeViewDnD.bind(header, rel);
		r.setAttribute(attrLabel, name);
		r.setAttribute(attrRel, rel);
		return r;
	}
	//
	public static function makeItem(name:String):TreeViewItem {
		var r:TreeViewItem = cast document.createDivElement();
		r.className = "item";
		var span = document.createSpanElement();
		span.appendChild(document.createTextNode(name));
		r.appendChild(span);
		r.title = name;
		return r;
	}
	public static function handleItemClick(e:MouseEvent, ?el:Element) {
		if (e != null) {
			e.preventDefault();
			if (el == null) el = cast e.target;
		} else if (el == null) return;
		var openAs = (cast el:TreeViewItem).yyOpenAs;
		var nav = openAs != null ? { kind: openAs } : null;
		GmlFile.open(el.innerText, el.getAttribute(attrPath), nav);
	}
	public static inline function makeItemShared(name:String, path:String, kind:String):TreeViewItem {
		var r = makeItem(name);
		r.setAttribute(attrPath, path.ptNoBS());
		r.setAttribute(attrIdent, name);
		if (kind != null) r.setAttribute(attrKind, kind);
		return r;
	}
	//
	public static function makeAssetItem(name:String, rel:String, path:String, kind:String):TreeViewItem {
		rel = rel.ptNoBS();
		var r = makeItemShared(name, path, kind);
		r.setAttribute(attrRel, rel);
		TreeViewDnD.bind(r, rel);
		var th = thumbMap[path];
		if (th != null) r.setAttribute(attrThumb, th);
		r.addEventListener(Preferences.current.singleClickOpen ? "click" : "dblclick", handleItemClick);
		r.addEventListener("contextmenu", handleItemCtxMenu);
		return r;
	}
	//
	private static function openProject(e:MouseEvent) {
		e.preventDefault();
		var el:Element = cast e.target;
		if (!el.classList.contains("item")) el = el.parentElement;
		var path = el.getAttribute(attrPath);
		if (FileSystem.existsSync(path)) {
			Project.open(path);
		} else if (Project.current.path == "") {
			if (Dialog.showMessageBox({
				message: "Project is missing. Remove from recent project list?",
				buttons: ["Yes", "No"],
				cancelId: 1,
			}) == 0) {
				RecentProjects.remove(path);
				el.parentElement.removeChild(el);
			}
		}
	}
	public static function makeProject(name:String, path:String) {
		var r = makeItemShared(name, path, "project");
		r.title = path;
		r.addEventListener(Preferences.current.singleClickOpen ? "click" : "dblclick", openProject);
		r.addEventListener("contextmenu", handleItemCtxMenu);
		return r;
	}
	//
	public static var openPaths:Array<String> = [];
	public static function saveOpen() {
		var r:Array<String> = [];
		for (dir in element.querySelectorEls('.$clDir.$clOpen')) {
			r.push(dir.getAttribute(attrRel));
		}
		openPaths = r;
	}
	public static function restoreOpen(?paths:Array<String>) {
		var paths = paths != null ? paths : openPaths;
		var el = element;
		for (path in paths) {
			var epath = tools.NativeString.escapeProp(path);
			var dir = el.querySelector('.dir[$attrRel="$epath"]');
			if (dir != null) {
				dir.classList.add(clOpen);
				ensureThumbs(dir);
			}
		}
	}
	//
	public static function init() {
		element = document.querySelectorAuto(".treeview");
		if (element == null) element = document.createDivElement();
		thumbStyle = document.querySelectorAuto("#tree-thumbs");
		thumbSheet = cast thumbStyle.sheet;
		var EventEmitter = ace.AceWrap.require("ace/lib/event_emitter").EventEmitter;
		ace.extern.AceOOP.implement(TreeView, EventEmitter);
	}
	// EventEmitter:
	@:native("_emit") public static dynamic function emit<E:{}>(eventName:String, ?e:E):Dynamic {
		throw "EventEmitter is not hooked for TreeView!";
	}
	@:native("_signal") public static dynamic function signal<E>(eventName:String, e:E):Void {
		throw "EventEmitter is not hooked for TreeView!";
	}
}
typedef TreeViewQuery = {
	?extra:String,
	?path:String,
	?kind:String,
	?rel:String,
	?ident:String,
};
extern class TreeViewDir extends DivElement {
	public var treeHeader:DivElement;
	public var treeItems:DivElement;
}
extern class TreeViewItem extends DivElement {
	public var yyOpenAs:FileKind;
}
