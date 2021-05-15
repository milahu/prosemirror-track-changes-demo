// prosemirror "track changes" demo with fiduswriter ModTrack

// TODO allow to undelete a selected deletion ("random access undo")

import './style.css' // minimal css for fiduswriter ModTrack
// css classes are defined in
// fiduswriter/document/static/js/modules/schema/common/track.js
// fiduswriter/document/static/js/modules/editor/state_plugins/track/plugin.js

import "prosemirror-view/style/prosemirror.css" // set white-space: pre-wrap, etc
import "prosemirror-menu/style/menu.css"
import "prosemirror-example-setup/style/style.css" // .ProseMirror-prompt, etc

import {EditorState, Plugin} from "prosemirror-state"
import {EditorView} from "prosemirror-view"
import {Schema, DOMParser} from "prosemirror-model"
import {schema} from "prosemirror-schema-basic"
import {exampleSetup} from "prosemirror-example-setup"

//import applyDevTools from "prosemirror-dev-tools";
// dependencies: "prosemirror-dev-tools": "*", "react": "*", "react-dom": "*", "unstated": "*"


// needed to show/hide the menuBar on focus/blur
// https://discuss.prosemirror.net/t/handling-focus-in-plugins/1981/6
//import { focusPlugin } from "./discuss.prosemirror.net/focus-plugin.js"

import { ModTrack, amendTransaction } from "./github.com/fiduswriter/fiduswriter/fiduswriter/document/static/js/modules/editor/track/index.js"
import { trackPlugin } from "./github.com/fiduswriter/fiduswriter/fiduswriter/document/static/js/modules/editor/state_plugins"
import * as TrackSchema from "./github.com/fiduswriter/fiduswriter/fiduswriter/document/static/js/modules/schema/common/track.js"
import { buildEditorKeymap } from "./github.com/fiduswriter/fiduswriter/fiduswriter/document/static/js/modules/editor/keymap"
import { docSchema } from "./github.com/fiduswriter/fiduswriter/fiduswriter/document/static/js/modules/schema/document"

import { buildKeymap } from "prosemirror-example-setup"
import { baseKeymap } from "prosemirror-commands"
import { keymap } from 'prosemirror-keymap'



class TextEditor {

  constructor() {

    this.docSource = document.querySelector('#edit-me');

    const customSchema = new Schema({
      nodes: schema.spec.nodes,
      marks: {
        ...schema.spec.marks,

        insertion: TrackSchema.insertion,
        deletion: TrackSchema.deletion,
        format_change: TrackSchema.format_change,
        // TODO function TrackSchema.parseTracks ?
      },
    })

    this.schema = {
      //...schema,
      //...docSchema,
      ...customSchema,
    }

    // fiduswriter statePlugins are inited in fiduswriter/document/static/js/modules/editor/collab/doc.js
    this.plugins = [];

    this.plugins.push(keymap(buildEditorKeymap(this.schema))); // needed for deletions -> setMeta('inputType'
    this.plugins.push(keymap(buildKeymap(this.schema)));
    this.plugins.push(keymap(baseKeymap));

    this.plugins.push(trackPlugin({editor: this}));

    var examplePlugins = exampleSetup({
      schema: docSchema,
      menuBar: true,
      floatingMenu: true,
    }).filter(p => ( // remove key handlers [quickfix]
      !Boolean(p.props?.handleKeyDown) &&
      !Boolean(p.props?.handleTextInput)
    ));
    this.plugins.push(...examplePlugins);
    //console.log('TextEditor examplePlugins', examplePlugins);

    //plugins.push(focusPlugin);

    // replace document with editor
    const editorElement = document.createElement('div');
    editorElement.classList.add('text-editor')
    //editorElement.setAttribute('lang', this.docSource.getAttribute('lang'))
    this.docSource.parentNode.insertBefore(editorElement, this.docSource);
    this.docSource.style.display = 'none';
    this.docSource.classList.add('edit-original')

    // fiduswriter/fiduswriter/document/static/js/modules/editor/index.js initEditor
    let setFocus = false
    //this.app = {}; // not needed?
    this.clientTimeAdjustment = 0; // needed in amend_transaction.js
    this.user = { id: 0, username: "root" }; // needed in amend_transaction.js
    this.mod = {}; // modules
    this.docInfo = {};
    this.docInfo.updated = null;
    this.docInfo.access_rights = 'write-tracked'; // enable "track changes" for amend_transaction.js
    this.schema = docSchema
    this.view = new EditorView(
      editorElement, {
      state: EditorState.create({
        doc: DOMParser.fromSchema(this.schema).parse(this.docSource),
        plugins: this.plugins,
      }),
      handleDOMEvents: {
        focus: (view, _event) => {
          //console.log(`TextEditor focus`)
          if (!setFocus) {
            this.currentView = this.view
            // We focus once more, as focus may have disappeared due to
            // disappearing placeholders.
            setFocus = true
            view.focus()
            setFocus = false
          }
        }
      },
      dispatchTransaction: tr => {
        //console.log(`TextEditor dispatchTransaction`)
        const trackedTr = amendTransaction(tr, this.view.state, this)
        const {state: newState, transactions} = this.view.state.applyTransaction(trackedTr)
        this.view.updateState(newState)
        /*
        transactions.forEach(subTr => {
          const footTr = subTr.getMeta('footTr')
          if (footTr) {
            this.mod.footnotes.fnEditor.view.dispatch(footTr)
          }
        })
        */
        if (tr.steps) {
          this.docInfo.updated = new Date()
        }
        //this.mod.collab.doc.sendToCollaborators()
      }
    })
    this.currentView = this.view

    //applyDevTools(this.view);

    // mock footnote editor. needed by trackPlugin
    // fiduswriter/document/static/js/modules/editor/state_plugins/track/plugin.js
    this.mod.footnotes = { fnEditor: { view: {
      dispatch: () => undefined,
      state: { tr: { setMeta: function () { return this; } } }
    }}};

    new ModTrack(this);
  }
}

document.body.onload = function () {
  new TextEditor();
}
