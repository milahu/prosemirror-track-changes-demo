import fileImport from 'rollup-plugin-file-import'

export default {
  plugins: [
    {
      ...fileImport([
        {
          outputDir: __dirname + '/assets/csljson/', // absolute path to output directory
          extensions: ['.csljson'],
        },
      ]),
      enforce: 'post',
      apply: 'build'
    }
  ]
}
