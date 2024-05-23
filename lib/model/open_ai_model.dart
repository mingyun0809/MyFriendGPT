//Message (메시지 역할과 내용을 정리)

class Messages{
  late final String role;
  late final String content;

  Messages({required this.role, required this.content});

  /** 필수 매개변수 'role'과 'content'를 받아 객체를 초기화 */
  Messages.fromJson(Map<String, dynamic> json){
    role = json['role'];
    content = json['content'];
  }

  /** 객체를 JSON 형식의 맵으로 변환*/
  Map<String, dynamic> toJson(){
    final data = <String, dynamic>{};
    data["role"] = role;
    data["content"] = content;
    return data;
  }

  /** 객체를 맵 형식으로 변환*/
  Map<String, String> toMap(){
    return {"role": role, "content": content};
  }

  /** CopyWith을 사용해 원본 객체인 Messages를 변경하지 않고 새로운 객체를 생성*/
  Messages copyWith({String? role, String? content}){
    return Messages(role: role ?? this.role, content: content ?? this.content);
  }
}

//ChatCompletionModel (채팅 정보를 관리)

class ChatCompletionModel{
  late final String model;
  late final List<Messages> messages;
  late final bool stream;

  ChatCompletionModel({
    required this.model,
    required this.messages,
    required this.stream,
  });

  ChatCompletionModel.fromJson(Map<String, dynamic> json){
    model = json['model'];
    messages = List.from(json["messages"]).map((e) => Messages.fromJson(e)).toList();
    stream = json[stream];
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['model'] = model;
    data['messages'] = messages.map((e) => e.toJson()).toList();
    data['stream'] = stream;
    return data;
  }

}