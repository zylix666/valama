/*
 * src/ui/symbol_browser.vala
 * Copyright (C) 2012, 2013, Valama development team
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

using Gtk;
using Vala;

/**
 * Browser symbols.
 */
public class SymbolBrowser : UiElement {
    TreeView tree_view;
    private bool update_needed = true;
    private ulong build_init_id;

    public SymbolBrowser (ValamaProject? vproject=null) {
        if (vproject != null)
            project = vproject;

        tree_view = new TreeView();

        tree_view.insert_column_with_attributes (-1,
                                                 null,
                                                 new CellRendererPixbuf(),
                                                 "pixbuf",
                                                 2,
                                                 null);
        var tmrenderer = new CellRendererText();
        var tmcolumn = new TreeViewColumn.with_attributes (_("Symbol"), tmrenderer, "markup", null);
        tree_view.append_column (tmcolumn);
        tree_view.insert_column_with_attributes (-1,
        // TRANSLATORS: Type in programming context as data type.
                                                 _("Type"),
                                                 new CellRendererText(),
                                                 "text",
                                                 1,
                                                 null);
        var store = new TreeStore (3, typeof (string), typeof (string), typeof (Gdk.Pixbuf));
        tree_view.set_model (store);
        TreeIter iter;
        store.append (out iter, null);

        tree_view.sensitive = false;

        int state = -1;
        var timer_id = Timeout.add (800, () => {
            switch (state) {
                case 0:
                    store.set (iter, 0, "<i>" + Markup.escape_text (_("Loading")) + ".  </i>", -1);
                    ++state;
                    break;
                case 1:
                    store.set (iter, 0, "<i>" + Markup.escape_text (_("Loading")) + ".. </i>", -1);
                    ++state;
                    break;
                case 2:
                    store.set (iter, 0, "<i>" + Markup.escape_text (_("Loading")) + "...</i>", -1);
                    ++state;
                    break;
                default:
                    store.set (iter, 0, "<i>" + Markup.escape_text (_("Loading")) + "   </i>", -1);
                    state = 0;
                    break;
            }
            return true;
        });

        /*
         * NOTE: Build symbol table after threaded Guanako update has
         *       finished. This might be later than this point, so connect
         *       a single time to this signal.
         */
        build_init_id = project.guanako_update_finished.connect (() => {
            project.disconnect (build_init_id);
            Source.remove (timer_id);
            tree_view.sensitive = true;
            tmcolumn.set_attributes (tmrenderer, "text", 0);
            build();
        });

        var scrw = new ScrolledWindow (null, null);
        scrw.add (tree_view);

        this.notify["project"].connect (init);
        init();

        widget = scrw;
    }

    private void init() {
        project.packages_changed.connect (() => {
            if (!project.add_multiple_files)
                build();
            else
                update_needed = true;
        });
        project.notify["add-multiple-files"].connect (() => {
            if (!project.add_multiple_files && update_needed)
                build();
        });
    }

    public override void build() {
        update_needed = false;
        debug_msg (_("Run %s update!\n"), get_name());
        var store = new TreeStore (3, typeof (string), typeof (string), typeof (Gdk.Pixbuf));
        tree_view.set_model (store);

        TreeIter[] iters = new TreeIter[0];

        Guanako.iter_symbol (project.guanako_project.root_symbol, (smb, depth) => {
            if (smb.name != null) {
                TreeIter next;
                if (depth == 1)
                    store.append (out next, null);
                else
                    store.append (out next, iters[depth - 2]);
                string typename = get_symbol_type_name(smb);
                store.set (next, 0, smb.name, 1, typename.up(1) + typename.substring(1), 2, get_pixbuf_for_symbol (smb), -1);
                if (iters.length < depth)
                    iters += next;
                else
                    iters[depth - 1] = next;
            }
            return Guanako.IterCallbackReturns.CONTINUE;
        });
        debug_msg (_("%s update finished!\n"), get_name());
    }
}

// vim: set ai ts=4 sts=4 et sw=4
