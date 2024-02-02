//
//  APP.swift
//  picture2model
//
//  Created by 黄超 on 2024/2/2.
//

import RealityKit
import os
import Foundation

struct DataResponse:Codable {
    let message:String
    let code:Int
    let data:ModelData
}
struct ModelData:Codable {
    let rows:[Item]
}

struct DataRequest:Codable {
    let id:String
    var result:Int=1
    var error:String=""
}

struct Item:Codable {
    let id:String
    let modelFile:[ItemData]
}

struct ItemData:Codable {
    let fileUrl:String
}

func main(){
    
    getData()
   
    RunLoop.main.run()
}


func getData(){
    let url = URL(string: "https://oss.com/file?limit=1")!
    Task {
        do {
            let (data,_) = try await URLSession.shared.data(from:url)
            let res = try JSONDecoder().decode(DataResponse.self,from:data)
            print(res)
            if(res.data.rows.count==1){
                
                let dirPath = "/Users/name/Downloads/data/"+res.data.rows[0].id;
                var isDirectory:ObjCBool = true;
                let exists = FileManager.default.fileExists(atPath: dirPath, isDirectory: &isDirectory)
                
                if(exists){
                    try FileManager.default.removeItem(at: URL(fileURLWithPath: dirPath, isDirectory: true))
                }
                
                await withTaskGroup(of: (Bool).self){ group in
                    for (index,data) in res.data.rows[0].modelFile.enumerated() {
                        group.addTask{
                            await downloadImage(id: res.data.rows[0].id, url: data.fileUrl, fileName: "\(index).jpg")
                        }
                       
                    }
                    
                   
                }
                
                await toModel(id:res.data.rows[0].id)
                
                
            }else{
               next()
            }
        }catch{
            print(error)
            next()
        }
    }
}

func updateData(data:DataRequest) {
  
    let request = MultipartFormDataRequest(url:URL(string:"https://oss.com/generate")!)
    request.addTextField(named: "id", value: data.id)
    //request.addTextField(named: "result", value: String(data.result))
    request.addTextField(named: "err", value: data.error)
    
    if(data.result==1){
        do{
            let files = ["baked_mesh.obj","baked_mesh_ao0.png","baked_mesh_norm0.png","baked_mesh_tex0.png","baked_mesh.mtl","baked_mesh.usda"]
            for file in files {
                let modelUrl = URL(fileURLWithPath: "/Users/name/Downloads/data/"+data.id+"/output/"+file)
                let modelData = try Data(contentsOf: modelUrl)
                request.addDataField(named: file, data: modelData, mimeType: "img/jpeg")
            }
        }catch{
            print(error)
        }
    }
    
    print("Upload data...")
  
   URLSession.shared.dataTask(with: request) { data, response, error in
       if let _data = data {
           print(String(decoding: _data,as:UTF8.self))
       }
       
       next()
       
       
       
    }.resume()
}

func downloadImage(id:String,url:String,fileName:String) async ->Bool {
    let dirPath = "/Users/name/Downloads/data/"+id;
    var isDirectory:ObjCBool = true;
    let exists = FileManager.default.fileExists(atPath: dirPath, isDirectory: &isDirectory)
        
    if !exists {
        do{
           try FileManager.default.createDirectory(atPath:dirPath,withIntermediateDirectories: true)
        }catch{
            return false
        }
    }
    
    let outputUrl = URL(fileURLWithPath:dirPath)
    let saveUrl = outputUrl.appendingPathComponent(fileName)
    
    if let imageUrl = URL(string: url){
    
        do{
            let (fileURL,_) = try await URLSession.shared.download(from: imageUrl)
            try FileManager.default.copyItem(at: fileURL, to: saveUrl)
                
            return true
            
        }catch{
            return false
        }
        
    }else{
        return false
    }
    
}

func next(){
    DispatchQueue.main.asyncAfter(deadline:.now()+10){
        getData()
    }
}

func toModel(id:String) async {
    
    let inputFolderUrl = URL(fileURLWithPath: "/Users/name/Downloads/data/"+id, isDirectory: true)
    var maybeSession:PhotogrammetrySession? = nil
    
    do {
        maybeSession = try PhotogrammetrySession(input:inputFolderUrl)
        
        guard let session = maybeSession else {
             updateData(data: DataRequest(id: id,result: 2,error: "system error"))
            return
        }
        
        let waiter = Task {
           
                for try await output in session.outputs {
                    switch output {
                    case .processingComplete:
                        print("process complete")
                    case .requestComplete(_,_):
                        print("request complete")
                         updateData(data: DataRequest(id: id))
                    case .requestProgress(_, _):
                        print("processing")
                    case .inputComplete:
                        print("data ingestion is complete,beginning processing...")
                    case .invalidSample(_,let reason):
                        print("session...")
                         updateData(data: DataRequest(id: id,result: 2,error: reason))
                    case .skippedSample:
                        print("session skipped")
                         //updateData(data: DataRequest(id: id,result: 2,error: "session skipped"))
                    case .automaticDownsampling:
                        print("automatic donwsampling was applied.")
                    case .processingCancelled:
                        print("processing was cancelled.")
                         updateData(data: DataRequest(id: id,result: 2,error: "session cancelled"))
                    case .requestError(_, let error):
                         updateData(data: DataRequest(id: id,result: 2,error:"\(error)"))
                    @unknown default:
                         updateData(data: DataRequest(id: id,result: 2,error:"\(output)"))
                    }
                }
           
        }
        
       
        let outPath = "/Users/name/Downloads/data/"+id+"/output";
        try FileManager.default.createDirectory(atPath:outPath,withIntermediateDirectories: true)
        
        let outputUrl = URL(fileURLWithPath:outPath)
        let request = PhotogrammetrySession.Request.modelFile(url: outputUrl)
        
        try session.process(requests: [request])
        
      
    }catch{
         updateData(data: DataRequest(id: id,result: 2,error: "service error"))
    }
    
}

main()

