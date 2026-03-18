import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class SendEmailService {
  void sendEmail(String targetEmail, String subject, String description) async {
    String username = "vilakonsili@gmail.com";
    String password = "nmll snjf rfqz iitb";

    final smtpServer = SmtpServer(
      'smtp.gmail.com',
      port: 587,
      username: username,
      password: password,
    );

    final message = Message()
      ..from = Address(username, 'Purchase System')
      ..recipients.add(targetEmail)
      ..subject = subject
      ..text = description;

    try {
      final sendReport = await send(message, smtpServer);
      print('Email sent: $sendReport');
    } catch (e) {
      print('Email send error: $e');
    }
  }
}
