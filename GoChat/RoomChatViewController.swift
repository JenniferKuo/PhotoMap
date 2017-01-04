//
//  RoomChatViewController.swift
//  GoChat
//
//  Created by 鄭薇 on 2017/1/1.
//  Copyright © 2017年 LilyCheng. All rights reserved.
//
import UIKit
import JSQMessagesViewController
import MobileCoreServices
import AVKit
import Firebase
import FirebaseDatabase
import FirebaseStorage
import FirebaseAuth

class RoomChatViewController: JSQMessagesViewController {
    
    var messages = [JSQMessage]()
    var nickNamesDict = [NSAttributedString]()              //暱稱字典
    var avatarDict = [String:JSQMessagesAvatarImage]()      //頭貼字典
    var uid = String()
    
    //********選擇房間參考位址及房號
    //var targetRoomRef: FIRDatabaseReference?
    var targetRoomNum = String()
    let uuid: String =  UIDevice.current.identifierForVendor!.uuidString
    
    //********抓出訊息的根參考位址
    //private lazy var messageRef: FIRDatabaseReference = self.targetRoomRef!.child("messages")
    private lazy var roomRef: FIRDatabaseReference = FIRDatabase.database().reference().child("TripGifRooms").child("\(self.targetRoomNum)")
    private lazy var messageRef: FIRDatabaseReference = FIRDatabase.database().reference().child("TripGifRooms").child("\(self.targetRoomNum)").child("messages")
    fileprivate lazy var storageRef: FIRStorageReference = FIRStorage.storage().reference(forURL: "gs://tripgif-b205b.appspot.com")
    
    var room: Room? {
        didSet {
            title = room?.roomName
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("進來了...我要進的房號是" + self.targetRoomNum)
        //print(messageRef)
        
        //舊的observeUsers()
        observeMessages()
        //print("大頭照陣列\(avatarDict[uuid])")
        
        // set avatars
        collectionView?.collectionViewLayout.incomingAvatarViewSize = CGSize(width: kJSQMessagesCollectionViewAvatarSizeDefault, height: kJSQMessagesCollectionViewAvatarSizeDefault)
        collectionView?.collectionViewLayout.outgoingAvatarViewSize = CGSize(width: kJSQMessagesCollectionViewAvatarSizeDefault, height: kJSQMessagesCollectionViewAvatarSizeDefault)
        
        if let currentUser = FIRAuth.auth()?.currentUser{
            //self.senderId = currentUser.uid
            self.senderId = uuid
            if currentUser.isAnonymous == true
            {
                //根據roomUser senderId(uuid)去資料庫抓user的senderName
                //observeUsers(uuid: senderId)
            }else{
                //不會用到這裡
                self.senderId = FIRAuth.auth()?.currentUser?.uid
                self.senderDisplayName = ""
            }
        }
    }
//舊的，讀較慢
//    func observeUsers(){
//        print("start observe user")
//        FIRDatabase.database().reference().child("TripGifUsers")
//            .observe(FIRDataEventType.value){
//                (snapshot: FIRDataSnapshot) in
//                for child in snapshot.children.allObjects as! [FIRDataSnapshot]{
//                    let chatdict = child.value as! [String:AnyObject]
//                    //print("my user picture dict\(chatdict)")
//                    let avatarUrl = chatdict["UserImgUrl"] as! String
//                    let currentId = chatdict["uuid"] as! String
//                    //print("i want url\(avatarUrl)currentId\(currentId)")
//                    self.setupAvatar(url: avatarUrl, messageId: currentId)
//                }
//        }
//    }
    func observeUser(uuid:String){
        FIRDatabase.database().reference().child("TripGifUsers").child(uuid).observe(.value, with:{
            snapshot in
            if let dict = snapshot.value as? [String:AnyObject]
            {
                let avatarUrl = dict["UserImgUrl"] as! String
                
                self.setupAvatar(url: avatarUrl, messageId: uuid)
            }
        })
    }
    func setupAvatar(url: String, messageId:String){
        if url != ""{
            let fileUrl = NSURL(string: url)
            let data = NSData(contentsOf: fileUrl! as URL)
            let image = UIImage(data:data! as Data)
            let userImg = JSQMessagesAvatarImageFactory.avatarImage(with: image, diameter: 30)
            avatarDict[messageId] = userImg
            //print("i have image")
        }else{
            let avatar = UIImage(named:"user")
            avatarDict[messageId] = JSQMessagesAvatarImageFactory.avatarImage(with: avatar, diameter: 30)
            //預設的：JSQMessagesAvatarImageFactory.avatarImage(withPlaceholder: UIImage(named:"user"), diameter: 30)
            //print("i use default image")
        }
        //print("我的大頭照\(avatarDict[messageId])")
        collectionView.reloadData()
    }
    
    func observeMessages() {
        messageRef.observe(FIRDataEventType.childAdded){(snapshot: FIRDataSnapshot) in
            if let dict = snapshot.value as?[String: AnyObject]{
                let mediaType = dict["MediaType"] as! String         //以String的型態傳上server
                let senderId = dict["senderId"] as! String
                let senderName = dict["senderName"] as! String
                
                self.observeUser(uuid:senderId)
                
                switch mediaType{
                case "TEXT":
                    let text = dict["text"] as! String
                    self.messages.append(JSQMessage(senderId: senderId, displayName: senderName, text: text))
                case "PHOTO":
                    let fileUrl = dict["fileUrl"] as! String
                    let url = NSURL(string: fileUrl) //把url轉成NSURL
                    let data = NSData(contentsOf: url as! URL)
                    let picture = UIImage(data: data as! Data)
                    let photo = JSQPhotoMediaItem(image: picture)
                    self.messages.append(JSQMessage(senderId: senderId, displayName: senderName, media: photo))
                    
                    if self.senderId == senderId{//bubble tail turn right
                        photo?.appliesMediaViewMaskAsOutgoing = true
                    }else{//bubble tail turn left
                        photo?.appliesMediaViewMaskAsOutgoing = false
                    }
                    
                case "VIDEO":
                    let fileUrl = dict["fileUrl"] as! String
                    let video = NSURL(string: fileUrl)
                    let videoItem = JSQVideoMediaItem(fileURL: video as URL!, isReadyToPlay: true)
                    self.messages.append(JSQMessage(senderId: senderId, displayName: senderName, media: videoItem))
                    if self.senderId == senderId{                           //bubble tail turn right
                        videoItem?.appliesMediaViewMaskAsOutgoing = true
                    }else{                                                  //bubble tail turn left
                        videoItem?.appliesMediaViewMaskAsOutgoing = false
                    }
                default:
                    print("unknown data type")
                }
                self.collectionView.reloadData()
                self.scrollToBottom(animated: true)
            }
        }
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        print("已點傳送按鈕")
        let newMessage = messageRef.childByAutoId()
        let messageData: NSDictionary = ["text":text, "senderId":senderId, "senderName":senderDisplayName, "MediaType":"TEXT"]
        newMessage.setValue(messageData)
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        self.finishSendingMessage()
        self.scrollToBottom(animated: true)
    }
    
    override func didPressAccessoryButton(_ sender: UIButton!) {
        print("已點附件按鈕")
        //pick a photo or video
        let sheet = UIAlertController(title:"傳送媒體訊息", message:"請選擇照片或影片", preferredStyle: UIAlertControllerStyle.actionSheet)
        let cancel = UIAlertAction(title:"取消", style:UIAlertActionStyle.cancel){(alert:UIAlertAction)in
        }
        let photoLibrary = UIAlertAction(title:"照片相簿", style:UIAlertActionStyle.default){(alert:UIAlertAction)in
            self.getMediaFrom(type: kUTTypeImage)
        }
        let videoLibrary = UIAlertAction(title:"影片相簿", style:UIAlertActionStyle.default){(alert:UIAlertAction)in
            self.getMediaFrom(type: kUTTypeMovie)
        }
        sheet.addAction(photoLibrary)
        sheet.addAction(videoLibrary)
        sheet.addAction(cancel)
        self.present(sheet, animated:true, completion:nil)
    }
    
    func getMediaFrom(type: CFString){
        print(type)
        let mediaPicker = UIImagePickerController()
        mediaPicker.delegate = self
        mediaPicker.mediaTypes = [type as String]                   //因為CFString不是string，所以要判斷時要轉成string型態
        self.present(mediaPicker, animated: true, completion: nil)
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        let message = messages[indexPath.item]
        let bubbleFactory = JSQMessagesBubbleImageFactory()
        if message.senderId == self.senderId{
            return bubbleFactory?.outgoingMessagesBubbleImage(with: UIColor(red:0.72, green:0.71, blue:0.71, alpha:1.0))
        }else{
            return bubbleFactory?.incomingMessagesBubbleImage(with: UIColor(red:0.72, green:0.71, blue:0.71, alpha:1.0))
        }
    }
    
    //設定大頭貼
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        let message = messages[indexPath.item]
        //return nil
        //預設方式：
        //return JSQMessagesAvatarImageFactory.avatarImage(withPlaceholder: UIImage(named:"user"), diameter: 30)
        //print("訊息sender\(message.senderId!)")
        //print("回傳大頭照\(avatarDict[(message.senderId)!])")
        return avatarDict[(message.senderId)!]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        //print ("訊息有幾則:\(messages.count)")
        return messages.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath)as! JSQMessagesCollectionViewCell
        return cell
    }
    
    //video message的對話泡泡
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, didTapMessageBubbleAt indexPath: IndexPath!) {
        print("didTapMessageBubbleAt indexPath:\(indexPath.item)")
        let message = messages[indexPath.item]
        if message.isMediaMessage{
            if let mediaItem = message.media as? JSQVideoMediaItem{
                let player = AVPlayer(url: mediaItem.fileURL)
                let playerViewController = AVPlayerViewController()
                playerViewController.player = player
                self.present(playerViewController, animated: true, completion: nil)
            }
        }
    }
    //小泡泡上的名字標籤
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat {
        return 15
    }
    override func collectionView(_ collectionView: JSQMessagesCollectionView?, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> NSAttributedString? {
        let message = messages[indexPath.item]
        switch message.senderId {
        case senderId:
            return nil
        default:
            guard let senderDisplayName = message.senderDisplayName else {
                assertionFailure()
                return nil
            }
            return NSAttributedString(string: senderDisplayName)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    /*
     // MARK: - Navigation
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
    func sendMedia(picture: UIImage?, video: NSURL?){   //把照片send然後存到Firebse Database
        print(picture)
        print(FIRStorage.storage().reference())         //印出Firebase Storage的URL
        if let picture = picture{                       //Media是照片
            let filePath = "\(uuid)/\(NSDate.timeIntervalSinceReferenceDate)"
            //用目前使用者和時間來區別不同的filePath
            print(filePath)
            let data = UIImageJPEGRepresentation(picture, 0.1)// return image as JPEG, 1表示部壓縮，把UIImage轉成NSData
            let metadata = FIRStorageMetadata()
            metadata.contentType = "image/jpg"
            FIRStorage.storage().reference().child(filePath).put(data!, metadata: metadata){(metadata, error) in //child:存照片的地方, put:上傳照片到storage
                if error != nil{
                    print(error?.localizedDescription)
                    return
                }
                //print(metadata)
                let fileUrl = metadata!.downloadURLs![0].absoluteString //!:not nil, Get the URL string from URL
                let newMessage = self.messageRef.childByAutoId()
                let messageData:NSDictionary = ["fileUrl": fileUrl, "senderId": self.senderId, "senderName": self.senderDisplayName, "MediaType": "PHOTO"]
                newMessage.setValue(messageData)
            }
        }else if let video = video{
            let filePath = "\(uuid)/\(NSDate.timeIntervalSinceReferenceDate)" //用目前使用者和時間來區別不同的filePath
            print(filePath)
            let data = NSData(contentsOf: video as URL)// return video as NSData
            let metadata = FIRStorageMetadata()
            metadata.contentType = "vedio/mp4"
            FIRStorage.storage().reference().child(filePath).put(data! as Data, metadata: metadata){(metadata, error) in //child:存照片的地方, put:上傳照片到storage
                if error != nil{
                    print(error?.localizedDescription)
                    return
                }
                //print(metadata)
                let fileUrl = metadata!.downloadURLs![0].absoluteString //!:not nil, Get the URL string from URL
                let newMessage = self.messageRef.childByAutoId()
                let messageData: NSDictionary = ["fileUrl": fileUrl, "senderId": self.senderId, "senderName": self.senderDisplayName, "MediaType": "VIDEO"]
                newMessage.setValue(messageData)
            }
        }
    }
}

extension RoomChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        //print("完成選擇媒體")
        //get the image info 可能之後有GPS資訊
        print(info)
        if let picture = info[UIImagePickerControllerOriginalImage] as? UIImage{//訊息是照片
            //let photo = JSQPhotoMediaItem(image: picture) //轉成JSQMessage
            //messages.append(JSQMessage(senderId: senderId, displayName: senderDisplayName, media: photo)) //讓message呈現照片
            sendMedia(picture: picture, video: nil)
        }
        else if let video = info[UIImagePickerControllerMediaURL]as? NSURL{
            let videoItem = JSQVideoMediaItem(fileURL: (video as NSURL!) as URL!, isReadyToPlay: true)
            messages.append(JSQMessage(senderId:senderId, displayName: senderDisplayName, media:videoItem))
            sendMedia(picture: nil, video:video)
        }
        self.dismiss(animated: true, completion: nil)
        collectionView.reloadData()
    }
}
