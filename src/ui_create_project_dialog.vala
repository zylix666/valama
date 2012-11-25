/**
 * src/project.vala
 * Copyright (C) 2012, Linus Seelinger <S.Linus@gmx.de>
 *
 * Valama is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Valama is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

using GLib;
using Gtk;

/*
 * Template selection widget; Can return selected item
 */
public class uiTemplateSelector {
    public uiTemplateSelector(){

        tree_view = new TreeView();
        var listmodel = new ListStore (2, typeof (string), typeof(Gdk.Pixbuf));
        tree_view.set_model (listmodel);

        tree_view.insert_column_with_attributes (-1,
                                                 null,
                                                 new CellRendererPixbuf(),
                                                 "pixbuf",
                                                 1);
        tree_view.insert_column_with_attributes (-1,
                                                 "Templates",
                                                 new CellRendererText(),
                                                 "markup",
                                                 0);

        available_templates = load_templates("en");

        foreach (ProjectTemplate template in available_templates) {
            TreeIter iter;
            listmodel.append (out iter);
            listmodel.set (iter, 0, "<b>" + template.name + "</b>\n" + template.description, 1, template.icon);
        }

        this.widget = tree_view;
    }

    TreeView tree_view;
    ProjectTemplate[] available_templates;
    public Widget widget;

    public ProjectTemplate? get_selected_template(){
        TreeModel model;
        var paths = tree_view.get_selection().get_selected_rows (out model);
        foreach (TreePath path in paths) {
            var indices = path.get_indices();
            return available_templates[indices[0]];
        }
        return null;
    }
}

/*
 * Project creation dialog; returns a valama_project of the created template-based project
 */

public valama_project? ui_create_project_dialog () {
    var dlg = new Dialog.with_buttons ("Choose project template",
                                       window_main,
                                       DialogFlags.MODAL,
                                       Stock.CANCEL,
                                       ResponseType.CANCEL,
                                       Stock.OPEN,
                                       ResponseType.ACCEPT,
                                       null);

    dlg.set_size_request (420, 300);
    dlg.resizable = false;

    var selector = new uiTemplateSelector();

    var box_main = new Box (Orientation.VERTICAL, 0);
    box_main.pack_start(selector.widget, true, true);


    var lbl = new Label("Project name");
    lbl.halign = Align.START;
    box_main.pack_start(lbl, false, false);

    var ent_proj_name_err = new Label ("");
    ent_proj_name_err.sensitive = false;

    Regex valid_chars = /^[a-z0-9.:_-]+$/i;  // keep "-" at the end!
    var ent_proj_name = new Entry.with_inputcheck (ent_proj_name_err, valid_chars, 5);
    ent_proj_name.set_placeholder_text("Project name");
    box_main.pack_start(ent_proj_name, false, false);
    box_main.pack_start(ent_proj_name_err, false, false);

    lbl = new Label("Location");
    lbl.halign = Align.START;
    box_main.pack_start(lbl, false, false);

    var chooser_target = new FileChooserButton ("New project location", Gtk.FileChooserAction.SELECT_FOLDER);
    box_main.pack_start(chooser_target, false, false);

    box_main.show_all();
    dlg.get_content_area().pack_start (box_main);
    var res = dlg.run();

    var template = selector.get_selected_template();
    string target_folder = chooser_target.get_current_folder();
    string proj_name = ent_proj_name.text;

    dlg.destroy();
    if (res == ResponseType.CANCEL)
        return null;

    if (template == null || proj_name.length == 0)
        return null;

    Process.spawn_command_line_sync(@"cp -R '$(template.path)' '$target_folder/$proj_name'");
    Process.spawn_command_line_sync(@"mv '$target_folder/$proj_name/template.vlp' '$target_folder/$proj_name/$proj_name.vlp'");

    var new_proj = new valama_project(@"$target_folder/$proj_name/$proj_name.vlp");
    new_proj.project_name = proj_name;
    return new_proj;
}
