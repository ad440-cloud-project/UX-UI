<template>
  <div id="file-drag-drop">
    <form ref="fileform">Drop the files here!</form>
    <div v-for="(file, key) in files" class="file-listing">
      {{ file.name }}
    </div>
    <a class="submit-button" v-on:click="submitFiles()" v-show="files.length > 0">Submit</a>
  </div>
</template>

<script>
  //Imports for session and axios usage below
  import axios from 'axios';
  import VueSession from 'vue-session';
  import Vue from 'vue';
  Vue.use(VueSession);

  export default {
    //Local variable to store files
    data(){
        return{
          files: [],
        }
      },

    mounted(){
      //Grab a SAS Token via the method that calls the API
      this.getSasToken();

      /*Listen to all of the drag events and bind an event listener to each
      for the fileform. */
      ['drag', 'dragstart', 'dragend', 'dragover', 'dragenter', 'dragleave', 'drop'].forEach( function( evt ) {
      /* For each event add an event listener that prevents the default action
        (opening the file in the browser) and stop the propagation of the event (so
        no other elements open the file in the browser)*/
      this.$refs.fileform.addEventListener(evt, function(e){
        e.preventDefault();
        e.stopPropagation();
        }.bind(this), false);
        }.bind(this));
      
      //Add an event listener for drop to the form
      this.$refs.fileform.addEventListener('drop', function(e){
      
      //Capture the files from the drop event and add them to our local files array.
      for( let i = 0; i < e.dataTransfer.files.length; i++ ){
        
        //Check files for proper file type before pushing to files array
        if(this.fileTypeValidation(e.dataTransfer.files[i]))
          this.files.push( e.dataTransfer.files[i] );
        else{
          console.log(`${e.dataTransfer.files[i].name} is not a valid jpeg or png. File not added.`);
        }
      }
      }.bind(this));
    },

    methods: {
      //Method called when clicking the "submit" button.
      //Main method for uploading files to Azure.
      submitFiles(){
          
          let uri = this.$session.get('uri');
          let sasToken = this.$session.get('sasToken');
          
          //Iterate through the files submitted and upload
          while(this.files.length > 0){
            //Setup variables - we pop here so that uploaded items disappear from the list
            let file = this.files.pop();
            let fileName = file.name;

            //Upload file to Azure storage images container
            console.log(`Uploading ${fileName}...`)
            axios.put(uri + "/upload-" + this.getDate() + fileName + sasToken, file,
            {
              headers: {
              'x-ms-blob-type': 'BlockBlob',
              },
            }).then(function(){
              console.log('Success!');
            }).catch(function(){
              console.log('Failed!');
            });
          }
        },

      //Helper method to retrieve a UTC date and return in YYYYMMDDHHMMSS format
      getDate(){
        var date = new Date();

        return(date.getFullYear().toString()+
               pad2(date.getUTCMonth()+1)+
               pad2(date.getUTCDate())+
               pad2(date.getUTCHours())+
               pad2(date.getUTCMinutes())+
               pad2(date.getUTCSeconds()));
        
        //Since Date methods only return single digits, we sometimes need to add a 0
        function pad2(n) {return (n < 10 ? '0' : '') + n;}
      },

      //Checks submitted files for proper file types
      fileTypeValidation(file){

          //If a file is not of the allowed types, push filename to errorList
          if (!file.type.match(/^(image\/jpg|image\/jpeg|image\/png)$/)){
            return false;
          }
          else{
            //Validation passes
            return true;
          }
      },

      //Retrieves an object from Azure containing the images container URI and a SAS Token.
      //Stores object data in session variables.
      getSasToken(){
        axios
          .get(process.env.VUE_APP_SAS_API)
          .then(response => {
          this.$session.set("sasToken", response.data.token);
          this.$session.set("uri", response.data.uri);
          })
          .catch(error => (this.info = "sas "+error));
          console.log("Response: " + this.$session.get('sasToken'));
      }
    }
  }
</script>

<!-- Application styling -->
<style>
  form {
    display: block;
    height: 100px;
    width: 80%;
    background: #999;
    margin: auto;
    margin-top: 40px;
    text-align: center;
    line-height: 100px;
    border-radius: 4px;
    text-transform: uppercase;
    color: white;
    font-weight: bold;
  }

  a.submit-button{
    display: block;
    margin: auto;
    text-align: center;
    width: 200px;
    padding: 10px;
    text-transform: uppercase;
    background-color: #999;
    color: white;
    font-weight: bold;
    margin-top: 20px;
    border-radius: 4px;
  }

  .file-listing{
    width: 400px;
    margin: auto;
    padding: 8px;
    border-bottom: 1px solid #ddd;
  }
</style>