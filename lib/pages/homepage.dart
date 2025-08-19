import 'package:flutter/material.dart';

/////// Home Page of the app ///////

class HomePage extends StatefulWidget {
  final Function(int) updatePageIndex;
  final Map<String, int> pageIndices;

  const HomePage({
    super.key, 
    required this.updatePageIndex,
    required this.pageIndices,
  });

  @override
  _HomePageState createState() => _HomePageState();
}


class _HomePageState extends State<HomePage> {
  
  @override
  Widget build(BuildContext context){
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 18, 18, 18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
      ),

      body:Center(
        child: SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children:[
                homePageIcon(),
                const SizedBox(height: 30),
                bleButton(context, widget.updatePageIndex, widget.pageIndices),
                const SizedBox(height: 100)
              ]
            )
          )
        )
      )
    );
  }
}

///// Function for Home Page icon /////
SizedBox homePageIcon(){
  return SizedBox(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children:[
        Image.asset(
          'assets/chemical.png',
          scale: 4
        ),
        const SizedBox(
          height: 5,
        ),
        const Text(
          'UNM Stat',
          style: TextStyle(
            color: Color.fromARGB(255, 236, 236, 241),
            fontSize: 24,
            fontWeight: FontWeight.bold
          ),
        ),
        const SizedBox(
          height: 5,
        ),
        const Text(
          'Welcome to UNM Stat!',
          style: TextStyle(
            color: Color.fromARGB(255, 224, 224, 224),
            fontSize: 18,
            fontWeight: FontWeight.w600
          ),
        )
      ]
    )
  );
}

///// Function for BLE button /////
// Button navigate to ble page on pressed
SizedBox bleButton(BuildContext context, Function(int) updatePageIndex, Map<String, int> pageIndices){
  return SizedBox(
    height: 50,
    width: 230,
    child: ElevatedButton(
      onPressed: (){
        updatePageIndex(pageIndices['ble']!);
      },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.all(12),
        foregroundColor: Color.fromARGB(255, 236, 236, 241),
        backgroundColor: Color.fromARGB(255, 236, 236, 241),
      ),
      child: const Text(
        'Start Connection',
        style: TextStyle(
            color: Color.fromARGB(255, 18, 18, 18),
            fontSize: 18,
            fontWeight: FontWeight.w600
          ),
      ), 
    )
  );
}
