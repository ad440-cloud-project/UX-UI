<!-- Application styling -->
<style lang="scss">
.dropbox {
  outline: 2px dashed grey; /* the dash box */
  outline-offset: -10px;
  background: lightcyan;
  color: dimgray;
  padding: 10px 10px;
  min-height: 200px; /* minimum height */
  position: relative;
  cursor: pointer;
}

.dropbox:hover {
  background: lightblue; /* when mouse over to the drop zone, change color */
}

.dropbox p {
  font-size: 1.2em;
  text-align: center;
  padding: 50px 0;
}

div.file-listing {
  width: 400px;
  margin: auto;
  padding: 10px;
  border-bottom: 1px solid #ddd;
}

div.file-listing img {
  height: 100px;
}

div.remove-container {
  text-align: center;
}

div.remove-container a {
  color: red;
  cursor: pointer;
}

a.submit-button {
  display: block;
  margin: auto;
  text-align: center;
  width: 200px;
  padding: 10px;
  text-transform: uppercase;
  background-color: #ccc;
  color: white;
  font-weight: bold;
  margin-top: 20px;
}

a.submit-button.hover {
  background-color: black;
}

progress {
  width: 400px;
  margin: auto;
  display: block;
  margin-top: 20px;
  margin-bottom: 20px;
}
</style>

<template>
  <div id="file-drag-drop">
    <form ref="fileform">
      <h1>Upload images</h1>
      <div class="dropbox">
        <p>Drag your file(s) here to begin</p>
      </div>
    </form>
    <progress max="100" :value.prop="uploadPercentage"></progress>
    <div v-for="(file, key) in files" v-bind:key="file.id" class="file-listing">
      <img class="preview" v-bind:ref="'preview' + parseInt(key)"/>
      {{ file.name }}
      <div class="remove-container">
        <a class="remove" v-on:click="removeFile(key)">Remove</a>
      </div>
    </div>
    <a class="submit-button" v-on:click="submitFiles()" v-show="files.length > 0">Submit</a>
  </div>
</template>

<script>
//Imports for session and axios usage below
import axios from "axios";
import VueSession from "vue-session";
import Vue from "vue";
Vue.use(VueSession);

export default {
  //Local variable to store files
  data() {
    return {
      dragAndDropCapable: false,
      files: [],
      uploadPercentage: 0
    };
  },

  mounted() {
    /*Grab a SAS Token via the method that calls the API*/
    this.getSasToken();

    /*
        Determine if drag and drop functionality is capable in the browser
    */
    this.dragAndDropCapable = this.determineDragAndDropCapable();

    /*

    /*Listen to all of the drag events and bind an event listener to each
      for the fileform. */

    if (this.dragAndDropCapable) {
      [
        "drag",
        "dragstart",
        "dragend",
        "dragover",
        "dragenter",
        "dragleave",
        "drop"
      ].forEach(
        function(evt) {
          /* For each event add an event listener that prevents the default action
        (opening the file in the browser) and stop the propagation of the event (so
        no other elements open the file in the browser)*/
          this.$refs.fileform.addEventListener(
            evt,
            function(e) {
              e.preventDefault();
              e.stopPropagation();
            }.bind(this),
            false
          );
        }.bind(this)
      );

      //Add an event listener for drop to the form
      this.$refs.fileform.addEventListener(
        "drop",
        function(e) {
          //Capture the files from the drop event and add them to our local files array.
          for (let i = 0; i < e.dataTransfer.files.length; i++) {
            //Check files for proper file type before pushing to files array
            if (this.fileTypeValidation(e.dataTransfer.files[i]))
              this.files.push(e.dataTransfer.files[i]);
            else {
              console.log(
                `${
                  e.dataTransfer.files[i].name
                } is not a valid jpeg or png. File not added.`
              );
            }
          }
        }.bind(this)
      );
    }
  },

  methods: {
    /*
        Determines if the drag and drop functionality is in the
        window
    */
    determineDragAndDropCapable() {
      /*
          Create a test element to see if certain events
          are present that let us do drag and drop.
      */
      var div = document.createElement("div");

      /*
          Check to see if the `draggable` event is in the element
          or the `ondragstart` and `ondrop` events are in the element. If
          they are, then we have what we need for dragging and dropping files.

          We also check to see if the window has `FormData` and `FileReader` objects
          present so we can do our AJAX uploading
      */
      return (
        ("draggable" in div || ("ondragstart" in div && "ondrop" in div)) &&
        "FileReader" in window
      );
    },

    /* Method called when clicking the "submit" button. */
    /* Main method for uploading files to Azure. */

    submitFiles() {
      let uri = this.$session.get("uri");
      let sasToken = this.$session.get("sasToken");

      //Iterate through the files submitted and upload
      while (this.files.length > 0) {
        //Setup variables - we pop here so that uploaded items disappear from the list
        let file = this.files.pop();
        let fileName = file.name;

        //Upload file to Azure storage images container
        console.log(`Uploading ${fileName}...`);
        axios
          .put(uri + "/upload-" + this.getDate() + fileName + sasToken, file, {
            headers: {
              "x-ms-blob-type": "BlockBlob"
            },

            onUploadProgress: function(progressEvent) {
              this.uploadPercentage = parseInt(
                Math.round((progressEvent.loaded * 100) / progressEvent.total)
              );
            }.bind(this)
          })
          .then(function() {
            console.log("Success!");
          })
          .catch(function() {
            console.log("Failed!");
          });
      }
    },

    //Helper method to retrieve a UTC date and return in YYYYMMDDHHMMSS format
    getDate() {
      var date = new Date();

      return (
        date.getFullYear().toString() +
        pad2(date.getUTCMonth() + 1) +
        pad2(date.getUTCDate()) +
        pad2(date.getUTCHours()) +
        pad2(date.getUTCMinutes()) +
        pad2(date.getUTCSeconds())
      );

      //Since Date methods only return single digits, we sometimes need to add a 0
      function pad2(n) {
        return (n < 10 ? "0" : "") + n;
      }
    },

    //Checks submitted files for proper file types
    fileTypeValidation(file) {
      var FILE_TYPE = process.env.FILE_TYPE;

      //If a file is not of the allowed types, push filename to errorList
      if (!file.type.match(FILE_TYPE)) {
        return false;
      } else {
        //Validation passes
        return true;
      }
    },

    //Retrieves an object from Azure containing the images container URI and a SAS Token.
    //Stores object data in session variables.
    getSasToken() {
      axios
      .get(process.env.VUE_APP_SAS_API)
        //.get("https://ddfnapp.azurewebsites.net/v1/getSasToken")
        .then(response => {
          this.$session.set("sasToken", response.data.token);
          this.$session.set("uri", response.data.uri);
        })
        .catch(error => (this.info = "sas " + error));
      console.log("Response: " + this.$session.get("sasToken"));
    },

    /*
     Removes a select file the user has uploaded*/
    removeFile(key) {
      this.files.splice(key, 1);
    }
  }
};
</script>
