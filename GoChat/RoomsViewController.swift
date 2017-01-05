//
//  RoomsViewController.swift
//  GoChat
//
//  Created by 鄭薇 on 2016/12/19.
//  Copyright © 2016年 LilyCheng. All rights reserved.
//
import Foundation
import UIKit
import Firebase
import FirebaseDatabase

class RoomsViewController: UIViewController {
    
    // MARK: Properties
    var existRoom: Array<String> = []
    var userRoom = [String: Int]()
    var senderDisplayName: String?
    var newRoomTextField: UITextField?
    let uuid: String =  UIDevice.current.identifierForVendor!.uuidString
    var testValid = false
    private var roomRefHandle: FIRDatabaseHandle?
    private var rooms: [Room] = []  //本意是在tableview上列出所有已存在房間
    
    private lazy var roomRef: FIRDatabaseReference = FIRDatabase.database().reference().child("TripGifRooms")
    
    // MARK: TextField
    @IBOutlet weak var InputRoomName: UITextField!
    @IBOutlet weak var InputRoomNum: UITextField!
    
    // MARK: View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = senderDisplayName!   //將最上面標題設為 使用者暱稱
        observeRoom()
    }
    deinit {
        if let refHandle = roomRefHandle {
            roomRef.removeObserver(withHandle: refHandle)
        }
    }

    // MARK :Actions
    //登出
    func observeRoom(){
    FIRDatabase.database().reference().child("TripGifUsers").child(uuid).child("myRooms").observe(.value, with:{
            snapshot in
//            print("目前使用者有的房間")
            for child in snapshot.children{
                let room = (child as AnyObject).key as String
                print(room)
            }
        })
        FIRDatabase.database().reference().child("TripGifRooms").observe(.value, with:{
            snapshot in
//            print("目前存在的房間")
            for child in snapshot.children{
                let room = (child as AnyObject).key as String
                self.existRoom.append(room)
                print(room)
            }
        })

    }
    
    @IBAction func EditProfile(_ sender: Any) {
        let storyBoard : UIStoryboard = UIStoryboard(name: "Main", bundle:nil)
        let UserInfoVC = storyBoard.instantiateViewController(withIdentifier: "LoginVC")
        self.present(UserInfoVC, animated:true, completion:nil)
    }
    //創新房間到房間資料庫中
    @IBAction func NewRoom(_ sender: Any) {
        if InputRoomName?.text != ""{                                   //房間名的input field不可為空
            let roomName = self.InputRoomName.text                      //接到的房間名
            var randomRoomNum:UInt32 = arc4random_uniform(9999)         //亂數產生四位數房號
            validRoomNum(roomNum: String(randomRoomNum))
            while(testValid==true){
                randomRoomNum = arc4random_uniform(9999)
                validRoomNum(roomNum: String(randomRoomNum))
            }
            
            let newRoomRef = roomRef.child(String(randomRoomNum))       //定義firebase裡的reference
            let roomItem = ["RoomName":roomName!, "RoomNum": String(describing: randomRoomNum)]
            newRoomRef.setValue(roomItem)
            //print("房間ref: " + String(describing: newRoomRef))
            //print("房間name: " + roomName!)
            //print("房間num: " + String(describing: randomRoomNum))
            
            //創建成功小視窗
            let alert = UIAlertController(title: "成功創立房間！", message: "名稱:" + roomName! + "\n房號:" + String(describing: randomRoomNum), preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "確定", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }else{
            //創建失敗小視窗
            let alert = UIAlertController(title: "請務必輸入房名！", message: "您輸入的名字會作為新開聊天室名稱", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "確定", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
    }
    
    @IBAction func EnterRoom(_ sender: Any) {
        if InputRoomNum?.text != ""{                               //房號不可為空
            let countChar = InputRoomNum.text?.characters.count
            if countChar != 4{
                //房號四位數不對 失敗小視窗
                let alert = UIAlertController(title: "房號只能為四位數", message: "請重新輸入！", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "確定", style: UIAlertActionStyle.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                return
            }
            // 刷新user裡的room資料，擁有此房則true
            let roomNumber = (self.InputRoomNum.text)!
            validRoomNum(roomNum: roomNumber)
            print("房號是否存在\(self.testValid)")
            if(self.testValid == false){
                let alert = UIAlertController(title: "提示", message: "輸入的房號不存在", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "確定", style: UIAlertActionStyle.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                return
            }
            else{
            FIRDatabase.database().reference().child("TripGifUsers").child(uuid).child("myRooms").child(roomNumber).setValue(true)
            roomRef.observeSingleEvent(of: .value, with: { (snapshot) in
                if snapshot.value is NSNull{
                    print("不存在任何房間！")
                }else{
                    print("輸入了想進的房號是 " + self.InputRoomNum.text!)
                }
            })
        }
        }else{
        //房號空白 失敗小視窗
            let alert = UIAlertController(title: "請務必輸入房號", message: "沒輸房號怎麼進房呢？", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "確定", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
    }
    
    // MARK: Firebase related methods
    
// 檢查房號是否可用，若房號不在資料庫中，則為false，若找到房號，則回傳true
    private func validRoomNum(roomNum: String){
   
        for room in existRoom{
//            print("目前有的房間\(room)")
            if(roomNum == room){
                self.testValid = true
                return
            }
            else{
                self.testValid = false
            }
        }
    }
    
    // MARK: Navigation
    override func prepare(for segue:UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "ShowMapChat"{
            let chatVc = segue.destination as! RoomMapViewController
            let targetNum = self.InputRoomNum.text! as String
            chatVc.senderDisplayName = senderDisplayName!
            chatVc.targetRoomNum = targetNum
            print("傳segue進聊天地圖中...")
        }
        else{print("傳值error!!!!!!!!!!!")}
    }    
}
