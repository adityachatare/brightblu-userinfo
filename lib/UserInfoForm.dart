import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:async';
import 'package:dartssh2/dartssh2.dart';
import 'package:task_2/attributes.dart';

class UserInfoForm extends StatefulWidget {
  @override
  _UserInfoFormState createState() => _UserInfoFormState();
}

class _UserInfoFormState extends State<UserInfoForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _employmentStatusController =
      TextEditingController();
  final TextEditingController _employeeAddressController =
      TextEditingController();

  bool _isEditing = false;
  String? _docId; // Document ID for editing

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // Dispose controllers when not needed
    _nameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _genderController.dispose();
    _employmentStatusController.dispose();
    _employeeAddressController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final Map<String, String> _userData = {
        'name': _nameController.text,
        'age': _ageController.text,
        'email': _emailController.text,
        'dob': _dobController.text,
        'gender': _genderController.text,
        'employmentStatus': _employmentStatusController.text,
        'employeeAddress': _employeeAddressController.text,
      };

      if (_isEditing) {
        await _editUserData(_userData);
      } else {
        await _addUserData(_userData);
      }

      _formKey.currentState!.reset();
      setState(() {
        _isEditing = false;
        _docId = null;
        _clearControllers();
      });
    }
  }

  void _clearControllers() {
    _nameController.clear();
    _ageController.clear();
    _emailController.clear();
    _dobController.clear();
    _genderController.clear();
    _employmentStatusController.clear();
    _employeeAddressController.clear();
  }

  Future<void> _addUserData(Map<String, String> userData) async {
    Uint8List pdfData = await _generatePDFInMemory(userData);
    await _uploadToSFTP(pdfData, userData['name']!);

    var docRef =
        await FirebaseFirestore.instance.collection('users').add(userData);
    _docId = docRef.id;

    print('User data saved and PDF uploaded.');
    Fluttertoast.showToast(
        msg: "Data saved succesfully",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  Future<void> _editUserData(Map<String, String> userData) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(_docId)
        .update(userData);

    Uint8List newPdfData = await _generatePDFInMemory(userData);
    await _uploadToSFTP(newPdfData, userData['name']!);

    print('User data and PDF updated.');
    Fluttertoast.showToast(
        msg: "Data edited succesfully",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  Future<void> _deleteUserData(String docId, String name) async {
    await FirebaseFirestore.instance.collection('users').doc(docId).delete();
    await _removePDFFromSFTP(name);

    print('User data and PDF deleted.');
    Fluttertoast.showToast(
        msg: "Data deleted succesfully",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.green,
        textColor: Colors.white,
        fontSize: 16.0);
  }

  Future<Uint8List> _generatePDFInMemory(Map<String, String> userData) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(children: [
            pw.Text('Employee Personal Information',
                style: const pw.TextStyle(fontSize: 24)),
          ]),
          pw.SizedBox(height: 20),
          pw.Text('Name: ${userData['name']}'),
          pw.SizedBox(height: 20),
          pw.Text('Age: ${userData['age']}'),
          pw.SizedBox(height: 20),
          pw.Text('Email: ${userData['email']}'),
          pw.SizedBox(height: 20),
          pw.Text('Date Of Birth: ${userData['dob']}'),
          pw.SizedBox(height: 20),
          pw.Text('Gender: ${userData['gender']}'),
          pw.SizedBox(height: 20),
          pw.Text('Employment Status: ${userData['employmentStatus']}'),
          pw.SizedBox(height: 20),
          pw.Text('Employee Address: ${userData['employeeAddress']}'),
        ],
      ),
    ));
    return pdf.save();
  }

  Future<void> _uploadToSFTP(Uint8List pdfData, String username) async {
    final socket = await SSHSocket.connect(host, portNo);
    final client = SSHClient(
      socket,
      username: userid,
      onPasswordRequest: () => password,
    );

    try {
      final sftp = await client.sftp();
      try {
        await sftp.mkdir('/AdityaChatare');
      } catch (e) {
        // Ignore if folder exists
      }

      final remoteFile = await sftp.open(
        '/AdityaChatare/${username.replaceAll(" ", "").toLowerCase().toString()}.pdf',
        mode: SftpFileOpenMode.create | SftpFileOpenMode.write,
      );

      final stream = Stream.fromIterable([pdfData]);
      await remoteFile.write(stream);
      await remoteFile.close();

      print('PDF uploaded to SFTP successfully!');
    } catch (e) {
      print('SFTP upload failed: $e');
    } finally {
      client.close();
    }
  }

  Future<void> _removePDFFromSFTP(String username) async {
    final socket = await SSHSocket.connect(host, portNo);
    final client = SSHClient(
      socket,
      username: userid,
      onPasswordRequest: () => password,
    );

    try {
      final sftp = await client.sftp();
      await sftp.remove(
          '/AdityaChatare/${username.replaceAll(" ", "").toLowerCase().toString()}.pdf');
      print('PDF removed from SFTP successfully.');
    } catch (e) {
      print('Error removing PDF from SFTP: $e');
    } finally {
      client.close();
    }
  }

  void _loadUserDataForEditing(Map<String, dynamic> data, String docId) {
    setState(() {
      _isEditing = true;
      _docId = docId;

      _nameController.text = data['name']!;
      _ageController.text = data['age']!;
      _emailController.text = data['email']!;
      _dobController.text = data['dob']!;
      _genderController.text = data['gender']!;
      _employmentStatusController.text = data['employmentStatus']!;
      _employeeAddressController.text = data['employeeAddress']!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('User Info Form')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Form(
              key: _formKey,
              child: Expanded(
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) =>
                          value!.isEmpty ? 'Enter your name' : null,
                    ),
                    TextFormField(
                      controller: _ageController,
                      decoration: const InputDecoration(labelText: 'Age'),
                    ),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    TextFormField(
                      controller: _dobController,
                      decoration: const InputDecoration(labelText: 'DOB'),
                    ),
                    TextFormField(
                      controller: _genderController,
                      decoration: const InputDecoration(labelText: 'Gender'),
                    ),
                    TextFormField(
                      controller: _employmentStatusController,
                      decoration:
                          const InputDecoration(labelText: 'Employment Status'),
                    ),
                    TextFormField(
                      controller: _employeeAddressController,
                      decoration:
                          const InputDecoration(labelText: 'Employee Address'),
                    ),
                    ElevatedButton(
                      onPressed: _submitForm,
                      child: Text(_isEditing ? 'Update Data' : 'Submit'),
                    ),
                    const SizedBox(height: 20),
                    const Text('Employee Data Table',
                        style: TextStyle(fontSize: 20)),
                    const SizedBox(height: 10),
                    _buildEmployeeTable(), // Add Employee Table here
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeTable() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Age')),
            DataColumn(label: Text('Actions')),
          ],
          rows: snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            return DataRow(cells: [
              DataCell(Text(data['name'] ?? '')),
              DataCell(Text(data['age'] ?? '')),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.edit,
                      color: Colors.green,
                    ),
                    onPressed: () => _loadUserDataForEditing(data, doc.id),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                    onPressed: () => _deleteUserData(doc.id, data['name']),
                  ),
                ],
              )),
            ]);
          }).toList(),
        );
      },
    );
  }
}
