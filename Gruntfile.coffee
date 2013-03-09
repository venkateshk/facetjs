module.exports = (grunt) ->

  # Project configuration.
  grunt.initConfig {
    pkg: grunt.file.readJSON('package.json')

    coffee: {
      options: { }
      compile: {
        files: [
          {
            expand: true      # Enable dynamic expansion.
            cwd: 'src/'       # Src matches are relative to this path.
            src: ['*.coffee'] # Actual pattern(s) to match.
            dest: 'target/'   # Destination path prefix.
            ext: '.js'        # Dest filepaths will have this extension.
          }
          {
            expand: true
            cwd: 'src/driver/'
            src: ['*.coffee']
            dest: 'target/'
            ext: '.js'
          }
        ]
      }
    }

    watch: {
      coffee: {
        files: ['src/*.coffee', 'src/driver/*.coffee']
        tasks: ['coffee']
      }
    }

    compass: {

    }
  }

  grunt.loadNpmTasks('grunt-contrib-watch')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-contrib-compass')

  # Default task(s).
  grunt.registerTask('default', ['coffee'])
  return
