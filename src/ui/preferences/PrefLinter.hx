package ui.preferences;
import js.html.Element;
import parsers.linter.GmlLinterPrefs;
import gml.Project;
import ui.Preferences.*;
import gml.GmlAPI;
import gml.file.GmlFile;
using tools.HtmlTools;
import js.html.SelectElement;
import file.kind.misc.KSnippets;
import tools.macros.PrefLinterMacros.*;

/**
 * ...
 * @author ...
 */
class PrefLinter {
	static var selectOpts:Array<String> = ["inherit", "on", "off"];
	static var selectVals:Array<Bool> = [js.Lib.undefined, true, false];
	public static function build(out:Element, project:Project) {
		out = addGroup(out, "Linter");
		out.id = "pref-linter";
		var el:Element;
		//
		var opt:GmlLinterPrefs;
		if (project != null) {
			opt = project.properties.linterPrefs;
			if (opt == null) {
				opt = project.properties.linterPrefs = {};
			}
		} else opt = current.linterPrefs;
		function saveOpt() {
			if (project != null) {
				ui.project.ProjectProperties.save(project, project.properties);
			} else {
				Preferences.save();
			}
		}
		//
		function add(name:String,
			get:GmlLinterPrefs->Bool,
			set:GmlLinterPrefs->Null<Bool>->Void,
		defValue:Bool):Element {
			var initialValue = get(opt);
			if (project != null) {
				var options = PrefLinter.selectOpts.copy();
				var values = selectVals;
				var parentValue = get(current.linterPrefs);
				if (parentValue == null) parentValue = defValue;
				options[0] += ' (➜ ' + (parentValue ? "on" : "off") + ")";
				//
				var initialOption = options[values.indexOf(initialValue)];
				return addDropdown(out, name, initialOption, options, function(s) {
					var z = values[options.indexOf(s)];
					set(opt, z);
					saveOpt();
				});
			} else {
				if (initialValue == null) initialValue = defValue;
				return addCheckbox(out, name, initialValue, function(z) {
					set(opt, z);
					saveOpt();
				});
			}
		}
		addf("Syntax check on load", opt.onLoad);
		addf("Syntax check on save", opt.onSave);
		addf("Warn about missing semicolons", opt.requireSemicolons);
		addf("Warn about single `=` comparisons", opt.noSingleEquals);
		addf("Warn about conditions without ()", opt.requireParentheses);
		el = addf("Treat `var` as block-scoped", opt.blockScopedVar);
		el.title = "You can also use `#macro const var` and `#macro let var`";
	}
}
