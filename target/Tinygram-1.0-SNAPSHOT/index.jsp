<%@ page import="com.google.appengine.api.blobstore.BlobstoreServiceFactory" %>
<%@ page import="com.google.appengine.api.blobstore.BlobstoreService" %>

<%
    BlobstoreService blobstoreService = BlobstoreServiceFactory.getBlobstoreService();
%>

<!DOCTYPE html>
<meta charset="UTF-8">
<html>
<head>
    <title>Tinygram</title>

    <link href="accueil.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css">
    <script src="https://unpkg.com/mithril/mithril.js"></script>
    <script src="https://unpkg.com/jwt-decode/build/jwt-decode.js"></script>
    <script src="https://accounts.google.com/gsi/client" async defer></script>
</head>

<body>
    <script>
    var root = document.body 

    var textButton = "suivre";

    var classHeart = "fa fa-heart-o";

    var showModal = false;

    var userTest = ""

    var sourceImgTest = ""

    var legendTest = ""

    var postArray = [];

    var messageErreur = "";


    var Login = {
        user:null,
        is_connected:false,
        name:"",
        email:"",
        ID:"",
        picture:"",
        handleCredential: function(response) {
            console.log("callback called:"+response.credential)
            const responsePayload = jwt_decode(response.credential)

            console.log("ID: " + responsePayload.sub)
            console.log('Full Name: ' + responsePayload.name)
            console.log('Given Name: ' + responsePayload.given_name)
            console.log('Family Name: ' + responsePayload.family_name)
            console.log("Image URL: " + responsePayload.picture)
            console.log("Email: " + responsePayload.email)
            console.log(responsePayload.name + " is connected")

            Login.name = responsePayload.name.replace(" ","_")
            Login.email = responsePayload.email
            Login.ID = response.credential
            Login.picture = responsePayload.picture
            Login.is_connected = true

            NewPosts.loadList()

            m.redraw()
        }
    }

    function handleCredentialResponse(response) {
        console.log("callback called:"+response.credential)
        const url = "_ah/api/myApi/v1/Hello"+'?access_token=' + response.credential
        fetch(url).then(response => response.text()).then(data => Login.user = data)
        Login.handleCredential(response)
    }

    //composant représentant la fenêtre modale de création de post tinygram
    var ModalCreatePost = {
        postID:"",
        url:"",
		body:"",
        view: function(vnode) {
            return m("div", {class: "modalcreatepostwindow"}, 
                m("div", {class: "modalcreatepostblock"}, [
                m("p",{id:"createword"}, "Créer une nouvelle publication"),
                m("button", {onclick: function() {showModal = false;document.getElementById("home").style.position = "relative";document.getElementById("home").style.opacity=1;messageErreur = "";}}, [m("i", {class: "fa fa-remove"})]),
                m("input", {type:"file",id:"selectpictureinput",accept:"image/png, image/jpeg",onchange:function(){
                    var file = this.files[0];
                    var reader = new FileReader();
                    reader.onload = function(e) {
                        //console.log("e.target.result : "+e.target.result);
                        //srcImage = e.target.result;
                        var image = document.getElementById("postpicture");
                        image.src = e.target.result;
                    }
                    reader.readAsDataURL(file);
                    messageErreur = "";
                    
                }}),
                m("img", {id:"postpicture",src:""}),
                m("input", {id:"legendfield",type:"text",placeholder:"écrivez ici la légende de votre photo"}),
                m("input", {id:"createpost",type:"submit",onclick: function(){
                    //var newPost = document.createElement(m(PersonalizedPost, {user: "userTest", sourceImg: "sourceImgTest", legend:"legendTest"}));
                    //document.getElementsByClassName("thread").appendChild(newPost);
                    //m.render(document.body,m(PersonalizedPost, {user: "userTest", sourceImg: "le_cri.jpg", legend:"legendTest"}))
                    //console.log("document.getElementById(postpicture).src = "+document.getElementById("postpicture").src);
                    console.log("window.location.href (url de la page courante) : "+window.location.href);
                    if(window.location.href.startsWith(document.getElementById("postpicture").src)){
                        messageErreur = "Veuillez séléctionner une image pour publier le post";
                    }
                    else{ 
                        ModalCreatePost.url = document.getElementById("postpicture").src 
		                ModalCreatePost.body = document.getElementById("legendfield").value
                        ModalCreatePost.postMessage()
                        ModalCreatePost.uploadImage()
                        postArray.push(m(PersonalizedPost, {id:vnode.state.postID, user: Login.name, sourceImg: document.getElementById("postpicture").src, legend:document.getElementById("legendfield").value, cptlike:0}));
                        showModal = false
                        console.log(postArray)
                        document.getElementById("home").style.position = "relative"
                        document.getElementById("home").style.opacity=1
                    }
                    /*userTest="test";sourceImgTest=document.getElementById("postpicture").src;legendTest=document.getElementById("legendfield").value;showModal = false;document.getElementById("home").style.position = "relative";document.getElementById("home").style.opacity=1;*/
                }}, "publier"),
                m("p", messageErreur)
            ])
            )
        },
        postMessage: function() {
            return m.request({
         		method: "POST",
         		url: "_ah/api/myApi/v1/postMsg/"+Login.email,
                params: {'owner':Login.name,
                        //'url':"url",
                        'body':ModalCreatePost.body}
         	})
            .then(function(result) {
                console.log("got:",result)
                ModalCreatePost.postID = result.key.name
            })
        },
        uploadImage: function(){
            console.log("DANS UPLOAD IMAGE")
            return m.request({
         		method: "POST",
                enctype: "multipart/form-data",
         		url: "<%= blobstoreService.createUploadUrl("/upload") %>",
                params: {'foo': "some text",
                        'myFile': ModalCreatePost.url}
         	})
        }
    }

    //composant représentant un post personalisable
    var PersonalizedPost = {
        heartTest: "fa fa-heart-o",
        textButtonTest: "suivre",
        nbAbonnes: 0,
        nbLikes: 0,
        view: function(vnode) {
            
            return m("div",{class: "post"},
                [
                m("div",{class:"postbanner"} ,[m("div", {class:"userbanner"}, [m("img", {class: "userpicture",src:"homer.png"}),
                m("div", {class:"usertext"},vnode.attrs.user)]),
                m("div", {class:"nbabonnes"}, vnode.state.nbAbonnes+" abonnés "),
                m("div", {class: "followbutton"}, m("button", {
                    onclick: function(){if(vnode.state.textButtonTest == "suivre"){
                        vnode.state.textButtonTest = "suivi !";
                        vnode.state.nbAbonnes=1;
                        console.log("l'user a cliqué sur suivre "+vnode.state.textButtonTest);} 
                    else {
                        vnode.state.textButtonTest = "suivre";
                        console.log("l'user a cliqué sur suivi "+vnode.state.textButtonTest);
                    }
                }, type:"button"}, vnode.state.textButtonTest),
            )]),
                m("img", {class: "postpicture",src:vnode.attrs.sourceImg}),
                m("div", {class: "likebutton"}, m("button", {onclick: function(){
                    if(vnode.state.heartTest == "fa fa-heart-o"){
                        vnode.state.heartTest = "fa fa-heart";
                        vnode.state.nbLikes=1;
                        console.log("ID POST: "+vnode.attrs.id)
                        PersonalizedPost.likePost(vnode.attrs.id)
                        console.log("l'user a cliqué sur le coeur blanc "+vnode.state.heartTest);}
                    else {
                        //vnode.state.heartTest = "fa fa-heart-o";
                        console.log("l'user a cliqué sur le coeur noir "+vnode.state.heartTest);}
                } ,class:vnode.state.heartTest})),
            //m("div", {class:"nbjaime"}, vnode.state.nbLikes+" personnes ont aimé ce post"),
            m("div", {class:"cptlike"}, Number(vnode.attrs.cptlike)+Number(vnode.state.nbLikes)+" personnes ont liké ce post"),
            m("div", {class: "description"},vnode.attrs.legend),
                
                ])
        },
        likePost: function(postID){
            return m.request({
         		method: "POST",
         		url: "_ah/api/myApi/v1/like/"+postID,
         	})
            .then(function(result) {
                console.log("got:",result)
            })
        }
    }

    //composant représentant un post tinygram dans le fil de posts
    var Post = {
        view: function() {
            
            return m("div",{class: "post"},
                [
                m("div",{class:"postbanner"} ,[m("div", {class:"userbanner"}, [m("img", {class: "userpicture",src:"homer.png"}),
                 m("div", {class:"usertext"},"homer 44")]),
                 m("div", {class: "followbutton"}, m("button", {onclick: function(){if(textButton == "suivre")
                 {textButton = "suivi !";} 
                 else {textButton = "suivre";}
                }, type:"button"}, textButton),
            )]),
                 m("img", {class: "postpicture",src:"le_cri.jpg"}),
                 m("div", {class: "likebutton"}, m("button", {onclick: function(){if(classHeart == "fa fa-heart-o")
                {classHeart = "fa fa-heart"}
                else {classHeart = "fa fa-heart-o"}
            } ,class:classHeart})),
            m("div", {class: "description"},"mon premier post !"),
                
                ])
        }
    }

    var NewPosts = {
	    nextToken: "",
	    loadList: function() {
	        return m.request({
	            method: "GET",
                url: "_ah/api/myApi/v1/retrievePosts/"+Login.email
            })
	        .then(function(result) {
	        	console.log("got new posts:",result)
                result.items.map(function(item){
                    postArray.push(
                        m(PersonalizedPost, {
                            id: item.key.name, 
                            user: item.properties.ownerName, 
                            sourceImg: item.properties.url, 
                            legend: item.properties.body, 
                            cptlike: item.properties.cptlike
                        })
                    )
                })                
	            if ('nextPageToken' in result) {
		        	NewPosts.nextToken = result.nextPageToken
	            } else {
	            	NewPosts.nextToken = ""
	            }
            })
	    },
	    next: function() {
	        return m.request({
	            method: "GET",
	            url: "_ah/api/myApi/v1/retrievePosts/"+Login.email+"?next="+NewPosts.nextToken})
	        .then(function(result) {
	        	console.log("got new posts 2:",result)
	        	result.items.map(function(item){
                    postArray.push(
                        m(PersonalizedPost, {
                            id: item.key.name, 
                            user: item.properties.owner, 
                            sourceImg: item.properties.url, 
                            legend: item.properties.body, 
                            cptlike: item.properties.cptlike
                        })
                    )
                })
	            if ('nextPageToken' in result) {
		        	NewPosts.nextToken = result.nextPageToken
	            } else {
	            	NewPosts.nextToken = ""
	            }
            })
	    }
    }
    
    var postView = {
        view: function(){
            return postArray.map(function(item){
                return m(PersonalizedPost, {id:item.attrs.id, user: item.attrs.user, sourceImg: item.attrs.sourceImg, legend:item.attrs.legend, cptlike:item.attrs.cptlike});
            })
        }    
    }

    //c'est ici qu'est écrit le code qui s'affichera à l'écran de l'utilisateur
    m.mount(root, {
    view: function() {
        return m("div" , {id: "pagehome"},
        [m("div",{id: "home"},
            [m("header",{class:"banner"} ,[
                //m("div", {class: "title"}, m("p", "TinyGram")),
                m("div", {class: "banner_icons"},[
                    m("p", "TinyGram"),
                    m("a",{class: "homebutton",href:"#home" /*ce href permet de revenir en haut de la page lorsque l'utilisateur clique sur la maison*/},[m("i", {class:"fa fa-home fa-2x"})]),
                    m("button",{class: "createpostbutton", onclick: function(){showModal = true;
                        console.log("showModal = "+showModal);
                        var home = document.getElementById("home");
                        home.style.position = "fixed";/*lorsque la fenêtre modale est ouverte, l'arrière plan est immobile*/
                        home.style.backgroundColor = "black";
                    home.style.opacity = 0.5}},[m("i",{class:"fa fa-plus-square-o fa-2x"})]),
                    m("button",{class: "loginbutton"},[m("i",{class:'fa fa-user-circle-o fa-2x'})]),
                    m('div',{class:"g_id_signin", "data-type":"standard"}),
                    m('div',{id:"g_id_onload", "data-callback":"handleCredentialResponse", "data-client_id":"305866023480-undf89hsfe7vr49jr3jmckuu582esui8.apps.googleusercontent.com"}),
                    m("img",{"src":Login.picture}),
                ]),
            ]      
            ),
            m("div",{class:"thread"},[
                m("div", "Fil infini de posts"),
                m(PersonalizedPost, {user: userTest, sourceImg: sourceImgTest, legend:legendTest}),
                //m(PersonalizedPost, {user: "nathan", sourceImg:"le_cri.jpg", legend:"salut !"}),
                m(Post),
                m(postView),
            ]),
            m('button',{
                class: 'button is-link',
                onclick: function(e) {NewPosts.next()}
                }, "Next"),
        ]),showModal && m(ModalCreatePost)
    ])
        }
    }
    )

    </script>
</body>
</html>