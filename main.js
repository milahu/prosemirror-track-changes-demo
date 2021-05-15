// prosemirror "track changes" demo with fiduswriter ModTrack

// FIXME delete and replace operations
//   tr.getMeta('inputType')
//     is required in
//     fiduswriter/document/static/js/modules/editor/track/amend_transaction.js
//   setMeta('inputType'
//     is called in fiduswriter/document/static/js/modules/editor/keymap.js
//     but buildEditorKeymap has no effect

import './style.css'

import "prosemirror-view/style/prosemirror.css" // set white-space: pre-wrap, etc
import "prosemirror-menu/style/menu.css"
import "prosemirror-example-setup/style/style.css" // .ProseMirror-prompt, etc

/* minimal css for fiduswriter ModTrack -> style.css
  span.approved-insertion {
    background-color: rgba(0, 255, 0, 0.5);
  }
  span.approved-deletion {
    background-color: rgba(255, 0, 0, 0.5);
  }
*/

import {EditorState, Plugin} from "prosemirror-state"
import {EditorView} from "prosemirror-view"
import {Schema, DOMParser} from "prosemirror-model"
import {schema} from "prosemirror-schema-basic"
import {exampleSetup} from "prosemirror-example-setup"

import { ModTrack, amendTransaction } from "./github.com/fiduswriter/fiduswriter--develop/fiduswriter/document/static/js/modules/editor/track/index.js"

// needed to show/hide the menuBar on focus/blur
// https://discuss.prosemirror.net/t/handling-focus-in-plugins/1981/6
//import { focusPlugin } from "./discuss.prosemirror.net/focus-plugin.js"

import * as FiduswriterSchemaTrack from "./github.com/fiduswriter/fiduswriter--develop/fiduswriter/document/static/js/modules/schema/common/track.js"
import { trackPlugin } from "./github.com/fiduswriter/fiduswriter--develop/fiduswriter/document/static/js/modules/editor/state_plugins"
import { buildEditorKeymap } from "./github.com/fiduswriter/fiduswriter--develop/fiduswriter/document/static/js/modules/editor/keymap"
import { buildKeymap } from "prosemirror-example-setup"
import { baseKeymap } from "prosemirror-commands"
import { keymap } from 'prosemirror-keymap'

import { docSchema } from "./github.com/fiduswriter/fiduswriter--develop/fiduswriter/document/static/js/modules/schema/document"



class TextEditor {

  constructor() {

    this.docSource = document.querySelector('#edit-me');

    const customSchema = new Schema({
      nodes: schema.spec.nodes,
      marks: {
        ...schema.spec.marks,

        insertion: FiduswriterSchemaTrack.insertion,
        deletion: FiduswriterSchemaTrack.deletion,
        format_change: FiduswriterSchemaTrack.format_change,
        // TODO function FiduswriterSchemaTrack.parseTracks ?
      },
    })

    this.schema = {
      //...schema,
      ...docSchema,
      //...customSchema,
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
    }).filter(p => ( // remove key handlers [quickfix, but no effect]
      !Boolean(p.props?.handleKeyDown) &&
      !Boolean(p.props?.handleTextInput)
    ));
    this.plugins.push(...examplePlugins);
    console.log('TextEditor examplePlugins', examplePlugins);

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
    this.schema = docSchema
    this.view = new EditorView(
      editorElement, {
      state: EditorState.create({
        doc: DOMParser.fromSchema(this.schema).parse(this.docSource),
        plugins: this.plugins,
      }),
      handleDOMEvents: {
        focus: (view, _event) => {
          console.log(`TextEditor focus`)
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
        console.log(`TextEditor dispatchTransaction`)
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

    // needed by trackPlugin [have a better workaround?]
    this.mod.footnotes = {};
    this.mod.footnotes.fnEditor = {};
    this.mod.footnotes.fnEditor.view = this.view;

    new ModTrack(this);
  }
}

document.body.onload = function () {
  new TextEditor();
}
